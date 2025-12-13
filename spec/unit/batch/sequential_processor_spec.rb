# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../lib/monadic_chat/batch"

RSpec.describe MonadicChat::Batch::SequentialProcessor do
  let(:mock_completion) { instance_double("OpenAI::Completion") }
  let(:processor) { described_class.new(mock_completion) }
  let(:test_batches_dir) { Dir.mktmpdir("test_batches") }
  let(:temp_input_dir) { Dir.mktmpdir("test_input") }

  before do
    stub_const("MonadicChat::Batch::JobManager::BATCHES_DIR", test_batches_dir)
  end

  after do
    FileUtils.rm_rf(test_batches_dir)
    FileUtils.rm_rf(temp_input_dir)
  end

  describe "#initialize" do
    it "stores the completion instance" do
      expect(processor.completion).to eq(mock_completion)
    end

    it "starts with no job" do
      expect(processor.job).to be_nil
    end
  end

  describe "ACCUMULATION_MODES" do
    it "includes all valid modes" do
      expect(described_class::ACCUMULATION_MODES).to eq(%w[none append replace summary])
    end
  end

  describe "#start" do
    let(:input_file) do
      path = File.join(temp_input_dir, "input.txt")
      File.write(path, "First prompt\nSecond prompt\nThird prompt\n")
      path
    end

    before do
      allow(mock_completion).to receive(:run).and_return("Response text")
    end

    context "with valid input" do
      it "creates a job record with sequential mode" do
        job = processor.start(input_path: input_file, config: { model: "gpt-5-mini" })

        expect(job["job_id"]).to match(/^batch_/)
        expect(job["mode"]).to eq("sequential")
        expect(job["input"]["record_count"]).to eq(3)
      end

      it "processes all records" do
        expect(mock_completion).to receive(:run).exactly(3).times

        processor.start(input_path: input_file, config: { model: "gpt-5-mini" })
      end

      it "yields progress for each record" do
        progress_calls = []

        processor.start(input_path: input_file, config: { model: "gpt-5-mini" }) do |progress|
          progress_calls << progress
        end

        expect(progress_calls.size).to eq(3)
        expect(progress_calls[0][:index]).to eq(0)
        expect(progress_calls[1][:index]).to eq(1)
        expect(progress_calls[2][:index]).to eq(2)
      end

      it "marks job as completed on success" do
        job = processor.start(input_path: input_file, config: { model: "gpt-5-mini" })

        expect(job["status"]).to eq("completed")
        expect(job["stats"]["completed"]).to eq(3)
        expect(job["stats"]["failed"]).to eq(0)
      end

      it "stores results in job manager" do
        job = processor.start(input_path: input_file, config: { model: "gpt-5-mini" })

        results = MonadicChat::Batch::JobManager.get_results(job["job_id"])
        expect(results.size).to eq(3)
        expect(results[0][:text]).to eq("Response text")
      end
    end

    context "with accumulation mode none" do
      it "passes only current content to each request" do
        received_prompts = []
        allow(mock_completion).to receive(:run) do |params, **_kwargs|
          received_prompts << params["messages"].last["content"]
          "Response"
        end

        processor.start(
          input_path: input_file,
          config: { model: "gpt-5-mini", accumulation_mode: "none" }
        )

        expect(received_prompts[0]).to eq("First prompt")
        expect(received_prompts[1]).to eq("Second prompt")
        expect(received_prompts[2]).to eq("Third prompt")
      end
    end

    context "with accumulation mode append" do
      it "prepends previous results to current input" do
        call_count = 0
        received_prompts = []
        allow(mock_completion).to receive(:run) do |params, **_kwargs|
          received_prompts << params["messages"].last["content"]
          call_count += 1
          "Response #{call_count}"
        end

        processor.start(
          input_path: input_file,
          config: { model: "gpt-5-mini", accumulation_mode: "append" }
        )

        expect(received_prompts[0]).to eq("First prompt")
        expect(received_prompts[1]).to include("Previous results:")
        expect(received_prompts[1]).to include("Response 1")
        expect(received_prompts[1]).to include("Current input:")
        expect(received_prompts[1]).to include("Second prompt")
      end
    end

    context "with accumulation mode replace" do
      let(:template_file) do
        path = File.join(temp_input_dir, "template.txt")
        # Each line is a record - placeholder in each line
        File.write(path, "Context: {{PREVIOUS}} - Task one\nContext: {{PREVIOUS}} - Task two\n")
        path
      end

      it "replaces placeholder with previous result" do
        call_count = 0
        received_prompts = []
        allow(mock_completion).to receive(:run) do |params, **_kwargs|
          received_prompts << params["messages"].last["content"]
          call_count += 1
          "Response #{call_count}"
        end

        processor.start(
          input_path: template_file,
          config: {
            model: "gpt-5-mini",
            accumulation_mode: "replace",
            accumulation_placeholder: "{{PREVIOUS}}"
          }
        )

        expect(received_prompts[0]).to include("(No previous result)")
        expect(received_prompts[0]).to include("Task one")
        expect(received_prompts[1]).to include("Response 1")
        expect(received_prompts[1]).to include("Task two")
      end
    end

    context "with context_window setting" do
      let(:multi_input_file) do
        path = File.join(temp_input_dir, "multi.txt")
        File.write(path, "One\nTwo\nThree\nFour\n")
        path
      end

      it "limits previous results to context_window size" do
        call_count = 0
        received_prompts = []
        allow(mock_completion).to receive(:run) do |params, **_kwargs|
          received_prompts << params["messages"].last["content"]
          call_count += 1
          "Response #{call_count}"
        end

        processor.start(
          input_path: multi_input_file,
          config: {
            model: "gpt-5-mini",
            accumulation_mode: "append",
            context_window: 2
          }
        )

        # The 4th prompt should only include results 2 and 3, not 1
        expect(received_prompts[3]).to include("Response 2")
        expect(received_prompts[3]).to include("Response 3")
        expect(received_prompts[3]).not_to include("Response 1")
      end
    end

    context "with empty input" do
      let(:empty_file) do
        path = File.join(temp_input_dir, "empty.txt")
        File.write(path, "")
        path
      end

      it "raises an error" do
        expect {
          processor.start(input_path: empty_file, config: { model: "gpt-5-mini" })
        }.to raise_error(ArgumentError, /No records found/)
      end
    end

    context "with invalid accumulation mode" do
      it "raises an error" do
        expect {
          processor.start(
            input_path: input_file,
            config: { model: "gpt-5-mini", accumulation_mode: "invalid" }
          )
        }.to raise_error(ArgumentError, /Invalid accumulation_mode/)
      end
    end

    context "with API error on one record" do
      it "records error but continues processing" do
        call_count = 0
        allow(mock_completion).to receive(:run) do |_params, **_kwargs|
          call_count += 1
          raise StandardError, "API error" if call_count == 2

          "Response #{call_count}"
        end

        job = processor.start(input_path: input_file, config: { model: "gpt-5-mini" })

        expect(job["stats"]["completed"]).to eq(2)
        expect(job["stats"]["failed"]).to eq(1)

        results = MonadicChat::Batch::JobManager.get_results(job["job_id"])
        expect(results[1][:error]).to eq("API error")
      end
    end
  end

  describe "#retrieve_results" do
    it "returns results for a completed sequential job" do
      # Create a sequential job manually
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 2,
        config: {},
        mode: :sequential
      )

      # Store results
      results = [
        { custom_id: "rec-000001", text: "First result", error: nil },
        { custom_id: "rec-000002", text: "Second result", error: nil }
      ]
      MonadicChat::Batch::JobManager.set_results(job["job_id"], results)

      retrieved = processor.retrieve_results(job["job_id"])
      expect(retrieved.size).to eq(2)
      expect(retrieved[0][:text]).to eq("First result")
    end

    it "raises error for non-existent job" do
      expect {
        processor.retrieve_results("fake_job_id")
      }.to raise_error(ArgumentError, /Job not found/)
    end

    it "raises error for non-sequential job" do
      job = MonadicChat::Batch::JobManager.create(
        input_path: "/test",
        input_type: :text_file,
        record_count: 1,
        config: {},
        mode: :parallel
      )

      expect {
        processor.retrieve_results(job["job_id"])
      }.to raise_error(/not a sequential job/)
    end
  end

  describe "private #validate_model" do
    it "only allows GPT-5 series models" do
      expect {
        processor.start(
          input_path: File.join(temp_input_dir, "dummy.txt").tap { |p| File.write(p, "test") },
          config: { model: "gpt-4o" }
        )
      }.to raise_error(ArgumentError, /Only GPT-5 series/)
    end
  end
end
