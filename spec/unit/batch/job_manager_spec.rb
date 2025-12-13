# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../lib/monadic_chat/batch/job_manager"

RSpec.describe MonadicChat::Batch::JobManager do
  let(:test_batches_dir) { Dir.mktmpdir("test_batches") }

  before do
    stub_const("MonadicChat::Batch::JobManager::BATCHES_DIR", test_batches_dir)
  end

  after do
    FileUtils.rm_rf(test_batches_dir)
  end

  describe ".create" do
    it "creates a new job with correct structure" do
      job = described_class.create(
        input_path: "/path/to/input.txt",
        input_type: :text_file,
        record_count: 100,
        config: { model: "gpt-5-mini", system_prompt: "Be helpful" }
      )

      expect(job["job_id"]).to match(/^batch_\d{14}_[a-f0-9]{8}$/)
      expect(job["status"]).to eq("created")
      expect(job["mode"]).to eq("parallel")
      expect(job["input"]["path"]).to eq("/path/to/input.txt")
      expect(job["input"]["type"]).to eq("text_file")
      expect(job["input"]["record_count"]).to eq(100)
      expect(job["config"]["model"]).to eq("gpt-5-mini")
      expect(job["stats"]["total"]).to eq(100)
    end

    it "persists job to file" do
      job = described_class.create(
        input_path: "/path/to/input.txt",
        input_type: :text_file,
        record_count: 10,
        config: {}
      )

      job_file = File.join(test_batches_dir, "#{job["job_id"]}.json")
      expect(File.exist?(job_file)).to be true
    end

    it "supports sequential mode" do
      job = described_class.create(
        input_path: "/path/to/input.txt",
        input_type: :text_file,
        record_count: 10,
        config: {},
        mode: :sequential
      )

      expect(job["mode"]).to eq("sequential")
    end
  end

  describe ".load" do
    it "loads an existing job" do
      created_job = described_class.create(
        input_path: "/test/path",
        input_type: :csv_file,
        record_count: 50,
        config: { model: "gpt-5" }
      )

      loaded_job = described_class.load(created_job["job_id"])

      expect(loaded_job["job_id"]).to eq(created_job["job_id"])
      expect(loaded_job["input"]["path"]).to eq("/test/path")
      expect(loaded_job["config"]["model"]).to eq("gpt-5")
    end

    it "returns nil for non-existent job" do
      result = described_class.load("nonexistent_job_id")
      expect(result).to be_nil
    end
  end

  describe ".save" do
    it "updates the updated_at timestamp" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      original_time = job["updated_at"]
      sleep 1.1 # Sleep longer than 1 second to ensure timestamp changes
      job["status"] = "in_progress"
      described_class.save(job)

      loaded = described_class.load(job["job_id"])
      expect(loaded["updated_at"]).not_to eq(original_time)
    end

    it "persists changes to disk" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      job["status"] = "in_progress"
      described_class.save(job)

      loaded = described_class.load(job["job_id"])
      expect(loaded["status"]).to eq("in_progress")
    end
  end

  describe ".update_status" do
    it "updates the job status" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      updated = described_class.update_status(job["job_id"], "in_progress")

      expect(updated["status"]).to eq("in_progress")
    end

    it "accepts additional fields to update" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      updated = described_class.update_status(
        job["job_id"],
        "submitted",
        { openai_batch_id: "batch_xyz123" }
      )

      expect(updated["openai_batch_id"]).to eq("batch_xyz123")
    end

    it "raises error for non-existent job" do
      expect {
        described_class.update_status("fake_id", "completed")
      }.to raise_error(/Job not found/)
    end
  end

  describe ".update_from_openai" do
    it "updates job from OpenAI batch status" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 100,
        config: {}
      )

      openai_status = {
        "id" => "batch_abc123",
        "status" => "in_progress",
        "request_counts" => {
          "total" => 100,
          "completed" => 45,
          "failed" => 2
        },
        "output_file_id" => nil,
        "error_file_id" => nil
      }

      updated = described_class.update_from_openai(job["job_id"], openai_status)

      expect(updated["openai_batch_id"]).to eq("batch_abc123")
      expect(updated["status"]).to eq("in_progress")
      expect(updated["stats"]["completed"]).to eq(45)
      expect(updated["stats"]["failed"]).to eq(2)
    end

    it "updates file IDs when batch completes" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 10,
        config: {}
      )

      openai_status = {
        "id" => "batch_abc123",
        "status" => "completed",
        "request_counts" => { "total" => 10, "completed" => 10, "failed" => 0 },
        "output_file_id" => "file-output123",
        "error_file_id" => nil
      }

      updated = described_class.update_from_openai(job["job_id"], openai_status)

      expect(updated["files"]["output_file_id"]).to eq("file-output123")
    end
  end

  describe ".list" do
    it "returns all jobs" do
      3.times do |i|
        described_class.create(
          input_path: "/test#{i}",
          input_type: :text_file,
          record_count: i + 1,
          config: {}
        )
      end

      jobs = described_class.list
      expect(jobs.size).to eq(3)
    end

    it "returns jobs in reverse chronological order" do
      first_job = described_class.create(
        input_path: "/first",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      sleep 1.1 # Sleep longer than 1 second to ensure different timestamps

      second_job = described_class.create(
        input_path: "/second",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      jobs = described_class.list
      expect(jobs[0]["job_id"]).to eq(second_job["job_id"])
      expect(jobs[1]["job_id"]).to eq(first_job["job_id"])
    end

    it "filters by status" do
      job1 = described_class.create(
        input_path: "/test1",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )
      described_class.update_status(job1["job_id"], "completed")

      described_class.create(
        input_path: "/test2",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      completed_jobs = described_class.list(status: "completed")
      expect(completed_jobs.size).to eq(1)
      expect(completed_jobs[0]["status"]).to eq("completed")
    end

    it "returns empty array when no jobs exist" do
      jobs = described_class.list
      expect(jobs).to eq([])
    end
  end

  describe ".delete" do
    it "removes the job file" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      result = described_class.delete(job["job_id"])
      expect(result).to be true
      expect(described_class.load(job["job_id"])).to be_nil
    end

    it "returns false for non-existent job" do
      result = described_class.delete("nonexistent_id")
      expect(result).to be false
    end
  end

  describe ".exists?" do
    it "returns true for existing job" do
      job = described_class.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {}
      )

      expect(described_class.exists?(job["job_id"])).to be true
    end

    it "returns false for non-existent job" do
      expect(described_class.exists?("fake_job_id")).to be false
    end
  end

  describe ".set_mapping" do
    it "stores custom_id to source mapping" do
      job = described_class.create(
        input_path: "/test",
        input_type: :folder,
        record_count: 3,
        config: {}
      )

      mapping = {
        "rec-000001" => { "index" => 0, "source" => "file1.txt" },
        "rec-000002" => { "index" => 1, "source" => "file2.txt" },
        "rec-000003" => { "index" => 2, "source" => "file3.txt" }
      }

      described_class.set_mapping(job["job_id"], mapping)

      loaded = described_class.load(job["job_id"])
      expect(loaded["custom_id_mapping"]["rec-000001"]["source"]).to eq("file1.txt")
    end
  end

  describe "status constants" do
    it "defines all expected statuses" do
      expect(described_class::STATUS_CREATED).to eq("created")
      expect(described_class::STATUS_UPLOADING).to eq("uploading")
      expect(described_class::STATUS_SUBMITTED).to eq("submitted")
      expect(described_class::STATUS_VALIDATING).to eq("validating")
      expect(described_class::STATUS_IN_PROGRESS).to eq("in_progress")
      expect(described_class::STATUS_FINALIZING).to eq("finalizing")
      expect(described_class::STATUS_COMPLETED).to eq("completed")
      expect(described_class::STATUS_FAILED).to eq("failed")
      expect(described_class::STATUS_EXPIRED).to eq("expired")
      expect(described_class::STATUS_CANCELLED).to eq("cancelled")
    end
  end
end
