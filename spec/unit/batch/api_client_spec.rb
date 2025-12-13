# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/monadic_chat/batch/api_client"

RSpec.describe MonadicChat::Batch::ApiClient do
  let(:access_token) { "test_token_123" }
  let(:client) { described_class.new(access_token) }

  describe "#initialize" do
    it "stores the access token" do
      expect(client.access_token).to eq("test_token_123")
    end
  end

  describe ".parse_batch_results" do
    context "with Responses API format" do
      let(:jsonl_content) do
        <<~JSONL
          {"custom_id":"req-001","response":{"status_code":200,"body":{"id":"resp_123","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"The answer is 4."}]}],"usage":{"input_tokens":10,"output_tokens":5},"model":"gpt-5-mini"}}}
          {"custom_id":"req-002","response":{"status_code":200,"body":{"id":"resp_456","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Tokyo"}]}],"usage":{"input_tokens":15,"output_tokens":3},"model":"gpt-5-mini"}}}
        JSONL
      end

      it "parses all results" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results.size).to eq(2)
      end

      it "extracts custom_id" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:custom_id]).to eq("req-001")
        expect(results[1][:custom_id]).to eq("req-002")
      end

      it "extracts text from Responses API output" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:text]).to eq("The answer is 4.")
        expect(results[1][:text]).to eq("Tokyo")
      end

      it "includes usage information" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:usage]["input_tokens"]).to eq(10)
        expect(results[0][:usage]["output_tokens"]).to eq(5)
      end

      it "includes model information" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:model]).to eq("gpt-5-mini")
      end
    end

    context "with Chat Completions API format" do
      let(:jsonl_content) do
        <<~JSONL
          {"custom_id":"req-001","response":{"status_code":200,"body":{"id":"chatcmpl_123","choices":[{"message":{"role":"assistant","content":"Hello!"}}],"usage":{"prompt_tokens":5,"completion_tokens":2},"model":"gpt-4o-mini"}}}
        JSONL
      end

      it "extracts text from choices" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:text]).to eq("Hello!")
      end
    end

    context "with error responses" do
      let(:jsonl_content) do
        <<~JSONL
          {"custom_id":"req-001","error":{"message":"Rate limit exceeded","type":"rate_limit_error"}}
        JSONL
      end

      it "captures error information" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results[0][:error]["message"]).to eq("Rate limit exceeded")
        expect(results[0][:text]).to be_nil
      end
    end

    context "with empty lines" do
      let(:jsonl_content) do
        <<~JSONL
          {"custom_id":"req-001","response":{"status_code":200,"body":{"output_text":"Test"}}}

          {"custom_id":"req-002","response":{"status_code":200,"body":{"output_text":"Test2"}}}
        JSONL
      end

      it "skips empty lines" do
        results = described_class.parse_batch_results(jsonl_content)
        expect(results.size).to eq(2)
      end
    end
  end

  describe ".extract_text_from_output" do
    it "extracts text from output array" do
      output = [
        {
          "type" => "message",
          "content" => [
            { "type" => "output_text", "text" => "First part. " },
            { "type" => "output_text", "text" => "Second part." }
          ]
        }
      ]

      text = described_class.extract_text_from_output(output)
      expect(text).to eq("First part. Second part.")
    end

    it "handles empty output array" do
      text = described_class.extract_text_from_output([])
      expect(text).to eq("")
    end

    it "ignores non-message types" do
      output = [
        { "type" => "function_call", "name" => "test" },
        {
          "type" => "message",
          "content" => [{ "type" => "output_text", "text" => "Hello" }]
        }
      ]

      text = described_class.extract_text_from_output(output)
      expect(text).to eq("Hello")
    end
  end

  describe "constants" do
    it "defines BASE_URL" do
      expect(described_class::BASE_URL).to eq("https://api.openai.com/v1")
    end

    it "defines timeout values" do
      expect(described_class::OPEN_TIMEOUT).to eq(10)
      expect(described_class::READ_TIMEOUT).to eq(60)
    end
  end

  describe "ApiError" do
    it "is a StandardError subclass" do
      error = described_class::ApiError.new("Test error")
      expect(error).to be_a(StandardError)
      expect(error.message).to eq("Test error")
    end
  end
end
