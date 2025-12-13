# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../lib/monadic_chat/batch"

RSpec.describe MonadicChat::Batch::Processor do
  let(:access_token) { "test_token_123" }
  let(:processor) { described_class.new(access_token) }
  let(:test_batches_dir) { Dir.mktmpdir("test_batches") }
  let(:temp_input_dir) { Dir.mktmpdir("test_input") }

  before do
    stub_const("MonadicChat::Batch::JobManager::BATCHES_DIR", test_batches_dir)
    stub_const("MonadicChat::Batch::Processor::TEMP_DIR", Dir.mktmpdir("test_jsonl"))
  end

  after do
    FileUtils.rm_rf(test_batches_dir)
    FileUtils.rm_rf(temp_input_dir)
  end

  describe "#initialize" do
    it "creates an API client" do
      expect(processor.api_client).to be_a(MonadicChat::Batch::ApiClient)
      expect(processor.api_client.access_token).to eq(access_token)
    end

    it "starts with no job" do
      expect(processor.job).to be_nil
    end
  end

  describe "#list_jobs" do
    it "returns empty array when no jobs exist" do
      jobs = processor.list_jobs
      expect(jobs).to eq([])
    end

    it "returns all jobs" do
      # Create some test jobs directly
      3.times do |i|
        MonadicChat::Batch::JobManager.create(
          input_path: "/test#{i}",
          input_type: :text_file,
          record_count: i + 1,
          config: {}
        )
      end

      jobs = processor.list_jobs
      expect(jobs.size).to eq(3)
    end

    it "filters by status" do
      job1 = MonadicChat::Batch::JobManager.create(
        input_path: "/test1",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )
      MonadicChat::Batch::JobManager.update_status(job1["job_id"], "completed")

      MonadicChat::Batch::JobManager.create(
        input_path: "/test2",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      completed_jobs = processor.list_jobs(status: "completed")
      expect(completed_jobs.size).to eq(1)
    end
  end

  describe "#delete_job" do
    it "deletes an existing job" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      result = processor.delete_job(job["job_id"])
      expect(result).to be true
      expect(MonadicChat::Batch::JobManager.exists?(job["job_id"])).to be false
    end

    it "returns false for non-existent job" do
      result = processor.delete_job("fake_job_id")
      expect(result).to be false
    end
  end

  describe "#start" do
    let(:input_file) do
      path = File.join(temp_input_dir, "input.txt")
      File.write(path, "Line one\nLine two\nLine three\n")
      path
    end

    let(:mock_api_client) { instance_double(MonadicChat::Batch::ApiClient) }

    before do
      allow(MonadicChat::Batch::ApiClient).to receive(:new).and_return(mock_api_client)
    end

    context "with successful API calls" do
      before do
        allow(mock_api_client).to receive(:upload_file).and_return({
          "id" => "file-abc123",
          "filename" => "test.jsonl",
          "bytes" => 500
        })

        allow(mock_api_client).to receive(:create_batch).and_return({
          "id" => "batch_xyz789",
          "status" => "validating",
          "request_counts" => { "total" => 3, "completed" => 0, "failed" => 0 }
        })
      end

      it "creates a job record" do
        new_processor = described_class.new(access_token)
        job = new_processor.start(input_path: input_file, config: { model: "gpt-5-mini" })

        expect(job["job_id"]).to match(/^batch_/)
        expect(job["input"]["record_count"]).to eq(3)
        expect(job["config"]["model"]).to eq("gpt-5-mini")
      end

      it "uploads the JSONL file" do
        new_processor = described_class.new(access_token)

        expect(mock_api_client).to receive(:upload_file).with(anything)

        new_processor.start(input_path: input_file, config: {})
      end

      it "creates a batch with correct endpoint" do
        new_processor = described_class.new(access_token)

        expect(mock_api_client).to receive(:create_batch).with(
          hash_including(
            input_file_id: "file-abc123",
            endpoint: "/v1/responses"
          )
        )

        new_processor.start(input_path: input_file, config: { model: "gpt-5-mini" })
      end

      it "stores the OpenAI batch ID" do
        new_processor = described_class.new(access_token)
        job = new_processor.start(input_path: input_file, config: {})

        expect(job["openai_batch_id"]).to eq("batch_xyz789")
      end

      it "stores custom_id mapping" do
        new_processor = described_class.new(access_token)
        job = new_processor.start(input_path: input_file, config: {})

        mapping = job["custom_id_mapping"]
        expect(mapping).to have_key("rec-000001")
        expect(mapping["rec-000001"]["index"]).to eq(0)
      end
    end

    context "with empty input" do
      let(:empty_file) do
        path = File.join(temp_input_dir, "empty.txt")
        File.write(path, "")
        path
      end

      it "raises an error" do
        new_processor = described_class.new(access_token)

        expect {
          new_processor.start(input_path: empty_file, config: {})
        }.to raise_error(ArgumentError, /No records found/)
      end
    end

    context "with API error" do
      before do
        allow(mock_api_client).to receive(:upload_file)
          .and_raise(MonadicChat::Batch::ApiClient::ApiError, "Upload failed")
      end

      it "updates job status to failed" do
        new_processor = described_class.new(access_token)

        expect {
          new_processor.start(input_path: input_file, config: {})
        }.to raise_error(MonadicChat::Batch::ApiClient::ApiError)

        # Find the created job
        jobs = MonadicChat::Batch::JobManager.list
        expect(jobs.first["status"]).to eq("failed")
        expect(jobs.first["errors"].first["message"]).to eq("Upload failed")
      end
    end
  end

  describe "#check_status" do
    let(:mock_api_client) { instance_double(MonadicChat::Batch::ApiClient) }

    before do
      allow(MonadicChat::Batch::ApiClient).to receive(:new).and_return(mock_api_client)
    end

    it "raises error for non-existent job" do
      expect {
        processor.check_status("fake_job_id")
      }.to raise_error(ArgumentError, /Job not found/)
    end

    it "returns job without API call if no OpenAI batch ID" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      new_processor = described_class.new(access_token)
      result = new_processor.check_status(job["job_id"])

      expect(result["job_id"]).to eq(job["job_id"])
    end

    it "updates status from OpenAI API" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 10,
        config: {}
      )
      MonadicChat::Batch::JobManager.update_status(job["job_id"], "validating",
                                                   { "openai_batch_id" => "batch_abc123" })

      allow(mock_api_client).to receive(:get_batch).with("batch_abc123").and_return({
        "id" => "batch_abc123",
        "status" => "in_progress",
        "request_counts" => { "total" => 10, "completed" => 5, "failed" => 0 }
      })

      new_processor = described_class.new(access_token)
      result = new_processor.check_status(job["job_id"])

      expect(result["status"]).to eq("in_progress")
      expect(result["stats"]["completed"]).to eq(5)
    end
  end

  describe "#cancel" do
    let(:mock_api_client) { instance_double(MonadicChat::Batch::ApiClient) }

    before do
      allow(MonadicChat::Batch::ApiClient).to receive(:new).and_return(mock_api_client)
    end

    it "raises error for non-existent job" do
      expect {
        processor.cancel("fake_job_id")
      }.to raise_error(ArgumentError, /Job not found/)
    end

    it "cancels a running job via API" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 10,
        config: {}
      )
      MonadicChat::Batch::JobManager.update_status(job["job_id"], "in_progress",
                                                   { "openai_batch_id" => "batch_abc123" })

      allow(mock_api_client).to receive(:cancel_batch).with("batch_abc123").and_return({
        "id" => "batch_abc123",
        "status" => "cancelling",
        "request_counts" => { "total" => 10, "completed" => 3, "failed" => 0 }
      })

      new_processor = described_class.new(access_token)
      result = new_processor.cancel(job["job_id"])

      expect(result["status"]).to eq("cancelling")
    end

    it "updates status locally for jobs without OpenAI batch ID" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      new_processor = described_class.new(access_token)
      result = new_processor.cancel(job["job_id"])

      expect(result["status"]).to eq("cancelled")
    end
  end

  describe "#retrieve_results" do
    let(:mock_api_client) { instance_double(MonadicChat::Batch::ApiClient) }

    before do
      allow(MonadicChat::Batch::ApiClient).to receive(:new).and_return(mock_api_client)
    end

    it "raises error for non-existent job" do
      expect {
        processor.retrieve_results("fake_job_id")
      }.to raise_error(ArgumentError, /Job not found/)
    end

    it "raises error if job has no output file" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      new_processor = described_class.new(access_token)

      expect {
        new_processor.retrieve_results(job["job_id"])
      }.to raise_error(/no output file/)
    end

    it "retrieves and parses results" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 2,
        config: {}
      )

      # Set up completed job
      job["files"]["output_file_id"] = "file-output123"
      job["custom_id_mapping"] = {
        "rec-000001" => { "index" => 0, "source" => "input.txt" },
        "rec-000002" => { "index" => 1, "source" => "input.txt" }
      }
      MonadicChat::Batch::JobManager.save(job)

      jsonl_results = <<~JSONL
        {"custom_id":"rec-000002","response":{"status_code":200,"body":{"output":[{"type":"message","content":[{"type":"output_text","text":"Second"}]}]}}}
        {"custom_id":"rec-000001","response":{"status_code":200,"body":{"output":[{"type":"message","content":[{"type":"output_text","text":"First"}]}]}}}
      JSONL

      allow(mock_api_client).to receive(:get_file_content)
        .with("file-output123")
        .and_return(jsonl_results)

      new_processor = described_class.new(access_token)
      results = new_processor.retrieve_results(job["job_id"])

      # Results should be sorted by index
      expect(results.size).to eq(2)
      expect(results[0][:text]).to eq("First")
      expect(results[0][:index]).to eq(0)
      expect(results[1][:text]).to eq("Second")
      expect(results[1][:index]).to eq(1)
    end
  end
end
