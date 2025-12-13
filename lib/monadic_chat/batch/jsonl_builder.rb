# frozen_string_literal: true

require "json"

module MonadicChat
  module Batch
    # Builds JSONL files for OpenAI Batch API
    # Supports both Responses API and Chat Completions API formats
    class JsonlBuilder
      attr_reader :requests, :api_type

      # API endpoint constants
      API_RESPONSES = "/v1/responses"
      API_CHAT_COMPLETIONS = "/v1/chat/completions"

      def initialize(api_type: :responses)
        @api_type = api_type
        @requests = []
      end

      # Add a request to the batch
      # @param custom_id [String] Unique identifier for tracking
      # @param content [String] The input content/prompt
      # @param config [Hash] Configuration options (model, system_prompt, max_tokens, etc.)
      def add_request(custom_id:, content:, config: {})
        request = case @api_type
                  when :responses
                    build_responses_request(custom_id, content, config)
                  when :chat_completions
                    build_chat_completions_request(custom_id, content, config)
                  else
                    raise ArgumentError, "Unknown API type: #{@api_type}"
                  end

        @requests << request
        request
      end

      # Build requests from an array of records (from InputParser)
      # @param records [Array<Hash>] Records with :id and :content keys
      # @param config [Hash] Shared configuration for all requests
      def add_records(records, config: {})
        records.each do |record|
          add_request(
            custom_id: record[:id],
            content: record[:content],
            config: config
          )
        end
      end

      # Generate JSONL content as a string
      def to_jsonl
        @requests.map { |req| JSON.generate(req) }.join("\n")
      end

      # Write JSONL to a file
      # @param path [String] Output file path
      # @return [String] The path written to
      def write(path)
        File.write(path, to_jsonl + "\n")
        path
      end

      # Returns the number of requests
      def count
        @requests.size
      end

      # Clear all requests
      def clear
        @requests = []
      end

      private

      # Build a request for Responses API format
      def build_responses_request(custom_id, content, config)
        model = config[:model] || config["model"] || "gpt-5-mini"
        system_prompt = config[:system_prompt] || config["system_prompt"]
        max_tokens = config[:max_tokens] || config["max_tokens"] || 2000
        temperature = config[:temperature] || config["temperature"]
        reasoning_effort = config[:reasoning_effort] || config["reasoning_effort"]

        body = {
          "model" => model,
          "max_output_tokens" => max_tokens
        }

        # Build input - can be string or array with system/user messages
        if system_prompt && !system_prompt.empty?
          body["instructions"] = system_prompt
          body["input"] = content
        else
          body["input"] = content
        end

        # Optional parameters
        body["temperature"] = temperature if temperature
        if reasoning_effort
          body["reasoning"] = { "effort" => reasoning_effort }
        end

        {
          "custom_id" => custom_id,
          "method" => "POST",
          "url" => API_RESPONSES,
          "body" => body
        }
      end

      # Build a request for Chat Completions API format
      def build_chat_completions_request(custom_id, content, config)
        model = config[:model] || config["model"] || "gpt-4o-mini"
        system_prompt = config[:system_prompt] || config["system_prompt"]
        max_tokens = config[:max_tokens] || config["max_tokens"] || 2000
        temperature = config[:temperature] || config["temperature"]

        messages = []
        if system_prompt && !system_prompt.empty?
          messages << { "role" => "system", "content" => system_prompt }
        end
        messages << { "role" => "user", "content" => content }

        body = {
          "model" => model,
          "messages" => messages,
          "max_tokens" => max_tokens
        }

        body["temperature"] = temperature if temperature

        {
          "custom_id" => custom_id,
          "method" => "POST",
          "url" => API_CHAT_COMPLETIONS,
          "body" => body
        }
      end
    end
  end
end
