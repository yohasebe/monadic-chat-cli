# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "json"
require_relative "../../../lib/monadic_chat/batch/jsonl_builder"

RSpec.describe MonadicChat::Batch::JsonlBuilder do
  describe "Responses API format" do
    let(:builder) { described_class.new(api_type: :responses) }

    describe "#add_request" do
      it "creates a request with correct structure" do
        builder.add_request(
          custom_id: "req-001",
          content: "What is 2+2?",
          config: { model: "gpt-5-mini", max_tokens: 100 }
        )

        expect(builder.count).to eq(1)
        request = builder.requests.first

        expect(request["custom_id"]).to eq("req-001")
        expect(request["method"]).to eq("POST")
        expect(request["url"]).to eq("/v1/responses")
        expect(request["body"]["model"]).to eq("gpt-5-mini")
        expect(request["body"]["input"]).to eq("What is 2+2?")
        expect(request["body"]["max_output_tokens"]).to eq(100)
      end

      it "includes system prompt as instructions" do
        builder.add_request(
          custom_id: "req-001",
          content: "Translate this",
          config: { model: "gpt-5-mini", system_prompt: "You are a translator." }
        )

        request = builder.requests.first
        expect(request["body"]["instructions"]).to eq("You are a translator.")
        expect(request["body"]["input"]).to eq("Translate this")
      end

      it "includes optional parameters" do
        builder.add_request(
          custom_id: "req-001",
          content: "Test",
          config: {
            model: "gpt-5-mini",
            temperature: 0.7,
            reasoning_effort: "medium"
          }
        )

        request = builder.requests.first
        expect(request["body"]["temperature"]).to eq(0.7)
        expect(request["body"]["reasoning"]["effort"]).to eq("medium")
      end

      it "uses default model when not specified" do
        builder.add_request(custom_id: "req-001", content: "Test")

        request = builder.requests.first
        expect(request["body"]["model"]).to eq("gpt-5-mini")
      end
    end

    describe "#add_records" do
      it "adds multiple records at once" do
        records = [
          { id: "doc-001", content: "First document" },
          { id: "doc-002", content: "Second document" },
          { id: "doc-003", content: "Third document" }
        ]

        builder.add_records(records, config: { model: "gpt-5" })

        expect(builder.count).to eq(3)
        expect(builder.requests[0]["custom_id"]).to eq("doc-001")
        expect(builder.requests[1]["custom_id"]).to eq("doc-002")
        expect(builder.requests[2]["custom_id"]).to eq("doc-003")
      end
    end

    describe "#to_jsonl" do
      it "generates valid JSONL format" do
        builder.add_request(custom_id: "req-001", content: "First")
        builder.add_request(custom_id: "req-002", content: "Second")

        jsonl = builder.to_jsonl
        lines = jsonl.split("\n")

        expect(lines.size).to eq(2)
        expect { JSON.parse(lines[0]) }.not_to raise_error
        expect { JSON.parse(lines[1]) }.not_to raise_error
      end

      it "each line is a valid JSON object" do
        builder.add_request(custom_id: "req-001", content: "Test content")

        jsonl = builder.to_jsonl
        parsed = JSON.parse(jsonl.lines.first)

        expect(parsed).to be_a(Hash)
        expect(parsed["custom_id"]).to eq("req-001")
      end
    end

    describe "#write" do
      it "writes JSONL to file" do
        builder.add_request(custom_id: "req-001", content: "Test")

        Tempfile.create("test.jsonl") do |f|
          builder.write(f.path)

          content = File.read(f.path)
          expect(content).to include("req-001")
          expect(content).to end_with("\n")
        end
      end
    end

    describe "#clear" do
      it "removes all requests" do
        builder.add_request(custom_id: "req-001", content: "Test")
        expect(builder.count).to eq(1)

        builder.clear
        expect(builder.count).to eq(0)
      end
    end
  end

  describe "Chat Completions API format" do
    let(:builder) { described_class.new(api_type: :chat_completions) }

    describe "#add_request" do
      it "creates a request with messages array" do
        builder.add_request(
          custom_id: "req-001",
          content: "Hello",
          config: { model: "gpt-4o-mini" }
        )

        request = builder.requests.first

        expect(request["url"]).to eq("/v1/chat/completions")
        expect(request["body"]["messages"]).to be_an(Array)
        expect(request["body"]["messages"][0]["role"]).to eq("user")
        expect(request["body"]["messages"][0]["content"]).to eq("Hello")
        expect(request["body"]["max_tokens"]).to eq(2000)
      end

      it "includes system message when provided" do
        builder.add_request(
          custom_id: "req-001",
          content: "Translate this",
          config: { system_prompt: "You are a translator." }
        )

        request = builder.requests.first
        messages = request["body"]["messages"]

        expect(messages.size).to eq(2)
        expect(messages[0]["role"]).to eq("system")
        expect(messages[0]["content"]).to eq("You are a translator.")
        expect(messages[1]["role"]).to eq("user")
      end

      it "uses default model gpt-4o-mini" do
        builder.add_request(custom_id: "req-001", content: "Test")

        request = builder.requests.first
        expect(request["body"]["model"]).to eq("gpt-4o-mini")
      end
    end
  end

  describe "API type validation" do
    it "raises error for unknown API type" do
      builder = described_class.new(api_type: :unknown)

      expect {
        builder.add_request(custom_id: "req-001", content: "Test")
      }.to raise_error(ArgumentError, /Unknown API type/)
    end
  end
end
