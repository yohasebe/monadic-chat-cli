# frozen_string_literal: true

require "http"
require "json"

module MonadicChat
  module Batch
    # Client for OpenAI Batch API and Files API
    class ApiClient
      BASE_URL = "https://api.openai.com/v1"
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 60

      attr_reader :access_token

      def initialize(access_token)
        @access_token = access_token
      end

      # Upload a file to OpenAI Files API
      # @param file_path [String] Path to the JSONL file
      # @param purpose [String] Purpose of the file (default: "batch")
      # @return [Hash] Response from Files API including file ID
      def upload_file(file_path, purpose: "batch")
        url = "#{BASE_URL}/files"

        response = HTTP.headers("Authorization" => "Bearer #{@access_token}")
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .post(url, form: {
                         purpose: purpose,
                         file: HTTP::FormData::File.new(file_path)
                       })

        parse_response(response)
      end

      # Create a batch job
      # @param input_file_id [String] ID of the uploaded input file
      # @param endpoint [String] API endpoint (e.g., "/v1/responses" or "/v1/chat/completions")
      # @param completion_window [String] Completion window (default: "24h")
      # @param metadata [Hash] Optional metadata for the batch
      # @return [Hash] Response from Batch API including batch ID
      def create_batch(input_file_id:, endpoint:, completion_window: "24h", metadata: nil)
        url = "#{BASE_URL}/batches"

        body = {
          input_file_id: input_file_id,
          endpoint: endpoint,
          completion_window: completion_window
        }
        body[:metadata] = metadata if metadata

        response = HTTP.headers(json_headers)
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .post(url, json: body)

        parse_response(response)
      end

      # Get batch status
      # @param batch_id [String] ID of the batch
      # @return [Hash] Batch status including request_counts
      def get_batch(batch_id)
        url = "#{BASE_URL}/batches/#{batch_id}"

        response = HTTP.headers(json_headers)
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .get(url)

        parse_response(response)
      end

      # List all batches
      # @param limit [Integer] Number of batches to return (max 100)
      # @param after [String] Cursor for pagination
      # @return [Hash] List of batches
      def list_batches(limit: 20, after: nil)
        url = "#{BASE_URL}/batches"
        params = { limit: limit }
        params[:after] = after if after

        response = HTTP.headers(json_headers)
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .get(url, params: params)

        parse_response(response)
      end

      # Cancel a batch
      # @param batch_id [String] ID of the batch to cancel
      # @return [Hash] Updated batch status
      def cancel_batch(batch_id)
        url = "#{BASE_URL}/batches/#{batch_id}/cancel"

        response = HTTP.headers(json_headers)
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .post(url)

        parse_response(response)
      end

      # Get file content (for retrieving batch results)
      # @param file_id [String] ID of the file
      # @return [String] Raw file content (JSONL format)
      def get_file_content(file_id)
        url = "#{BASE_URL}/files/#{file_id}/content"

        response = HTTP.headers("Authorization" => "Bearer #{@access_token}")
                       .timeout(connect: OPEN_TIMEOUT, write: 300, read: 300)
                       .get(url)

        if response.status.success?
          response.body.to_s
        else
          error_body = response.body.to_s rescue "Unknown error"
          raise ApiError, "Failed to get file content: #{response.status} - #{error_body}"
        end
      end

      # Delete a file
      # @param file_id [String] ID of the file to delete
      # @return [Hash] Deletion confirmation
      def delete_file(file_id)
        url = "#{BASE_URL}/files/#{file_id}"

        response = HTTP.headers(json_headers)
                       .timeout(connect: OPEN_TIMEOUT, write: READ_TIMEOUT, read: READ_TIMEOUT)
                       .delete(url)

        parse_response(response)
      end

      # Parse batch results from JSONL content
      # @param jsonl_content [String] Raw JSONL content from output file
      # @return [Array<Hash>] Array of parsed results with custom_id and response/error
      def self.parse_batch_results(jsonl_content)
        results = []

        jsonl_content.each_line do |line|
          next if line.strip.empty?

          parsed = JSON.parse(line)
          result = {
            custom_id: parsed["custom_id"],
            status_code: parsed.dig("response", "status_code")
          }

          if parsed["response"] && parsed["response"]["body"]
            body = parsed["response"]["body"]

            # Extract text from Responses API format
            if body["output"]
              text = extract_text_from_output(body["output"])
              result[:text] = text
              result[:usage] = body["usage"]
              result[:model] = body["model"]
            # Extract text from Chat Completions API format
            elsif body["choices"]
              text = body.dig("choices", 0, "message", "content")
              result[:text] = text
              result[:usage] = body["usage"]
              result[:model] = body["model"]
            else
              result[:text] = body["output_text"] if body["output_text"]
              result[:raw_body] = body
            end
          elsif parsed["error"]
            result[:error] = parsed["error"]
          end

          results << result
        end

        results
      end

      # Extract text from Responses API output array
      # @param output [Array] Output array from Responses API
      # @return [String] Extracted text
      def self.extract_text_from_output(output)
        texts = []
        output.each do |item|
          if item["type"] == "message" && item["content"]
            item["content"].each do |content|
              texts << content["text"] if content["type"] == "output_text"
            end
          end
        end
        texts.join("")
      end

      private

      def json_headers
        {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json"
        }
      end

      def parse_response(response)
        body = response.body.to_s
        parsed = JSON.parse(body)

        if parsed["error"]
          raise ApiError, parsed["error"]["message"] || parsed["error"].to_s
        end

        parsed
      rescue JSON::ParserError
        raise ApiError, "Invalid JSON response: #{body[0..200]}"
      end

      # Custom error class for API errors
      class ApiError < StandardError; end
    end
  end
end
