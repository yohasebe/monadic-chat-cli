# frozen_string_literal: true

require "fileutils"
require_relative "input_parser"
require_relative "jsonl_builder"
require_relative "job_manager"
require_relative "api_client"

module MonadicChat
  module Batch
    # Main processor for batch operations
    # Orchestrates the entire batch processing workflow
    class Processor
      attr_reader :api_client, :job

      # Temp directory for JSONL files
      TEMP_DIR = "/tmp/monadic_chat_batch"

      def initialize(access_token)
        @api_client = ApiClient.new(access_token)
        @job = nil
      end

      # Start a new batch job (Parallel mode)
      # @param input_path [String] Path to input (file or folder)
      # @param config [Hash] Configuration options
      # @option config [String] :model Model to use
      # @option config [String] :system_prompt System prompt
      # @option config [Integer] :max_tokens Max tokens for response
      # @option config [Float] :temperature Temperature setting
      # @option config [String] :reasoning_effort Reasoning effort level
      # @return [Hash] The created job metadata
      def start(input_path:, config: {})
        # 0. Validate model (GPT-5 series only)
        model = config[:model] || config["model"] || "gpt-5-mini"
        validate_model(model)

        # 1. Parse input
        parser = InputParser.new(input_path)
        records = parser.parse

        raise ArgumentError, "No records found in input" if records.empty?

        # 2. Create job record
        @job = JobManager.create(
          input_path: parser.source_path,
          input_type: parser.source_type,
          record_count: records.size,
          config: config,
          mode: :parallel
        )

        begin
          # 3. Build JSONL
          jsonl_path = build_jsonl(records, config)
          JobManager.update_status(@job["job_id"], JobManager::STATUS_UPLOADING,
                                   { "files" => @job["files"].merge("jsonl_path" => jsonl_path) })

          # 4. Store custom_id mapping
          mapping = build_mapping(records)
          JobManager.set_mapping(@job["job_id"], mapping)

          # 5. Upload file
          upload_result = @api_client.upload_file(jsonl_path)
          input_file_id = upload_result["id"]

          @job = JobManager.update_status(@job["job_id"], JobManager::STATUS_SUBMITTED,
                                          { "files" => @job["files"].merge("input_file_id" => input_file_id) })

          # 6. Create batch
          endpoint = determine_endpoint(config[:model] || config["model"])
          batch_result = @api_client.create_batch(
            input_file_id: input_file_id,
            endpoint: endpoint,
            metadata: { "job_id" => @job["job_id"] }
          )

          # 7. Update job with OpenAI batch ID
          @job = JobManager.update_from_openai(@job["job_id"], batch_result)

          @job
        rescue StandardError => e
          JobManager.update_status(@job["job_id"], JobManager::STATUS_FAILED,
                                   { "errors" => [{ "message" => e.message }] })
          raise
        end
      end

      # Check and update job status
      # @param job_id [String] The job ID
      # @return [Hash] Updated job metadata
      def check_status(job_id)
        job = JobManager.load(job_id)
        raise ArgumentError, "Job not found: #{job_id}" unless job

        openai_batch_id = job["openai_batch_id"]
        return job unless openai_batch_id

        # Get status from OpenAI
        batch_status = @api_client.get_batch(openai_batch_id)
        JobManager.update_from_openai(job_id, batch_status)
      end

      # Wait for job completion with polling
      # @param job_id [String] The job ID
      # @param max_wait [Integer] Maximum wait time in seconds
      # @param interval [Integer] Polling interval in seconds
      # @yield [Hash] Called on each status check with current job state
      # @return [Hash, nil] Final job state or nil if timeout
      def wait_for_completion(job_id, max_wait: 86400, interval: 30)
        start_time = Time.now

        loop do
          elapsed = Time.now - start_time
          return nil if elapsed > max_wait

          job = check_status(job_id)
          yield job if block_given?

          case job["status"]
          when "completed"
            return job
          when "failed", "expired", "cancelled"
            return job
          else
            sleep interval
          end
        end
      end

      # Retrieve results for a completed job
      # @param job_id [String] The job ID
      # @return [Array<Hash>] Array of results with custom_id, text, and source info
      def retrieve_results(job_id)
        job = JobManager.load(job_id)
        raise ArgumentError, "Job not found: #{job_id}" unless job

        output_file_id = job.dig("files", "output_file_id")
        raise "Job has no output file. Status: #{job["status"]}" unless output_file_id

        # Get raw results
        jsonl_content = @api_client.get_file_content(output_file_id)
        raw_results = ApiClient.parse_batch_results(jsonl_content)

        # Enrich with source mapping
        mapping = job["custom_id_mapping"] || {}
        raw_results.map do |result|
          custom_id = result[:custom_id]
          source_info = mapping[custom_id] || {}

          result.merge(
            source: source_info["source"],
            index: source_info["index"]
          )
        end.sort_by { |r| r[:index] || 0 }
      end

      # Cancel a running job
      # @param job_id [String] The job ID
      # @return [Hash] Updated job metadata
      def cancel(job_id)
        job = JobManager.load(job_id)
        raise ArgumentError, "Job not found: #{job_id}" unless job

        openai_batch_id = job["openai_batch_id"]
        if openai_batch_id && %w[validating in_progress finalizing].include?(job["status"])
          batch_status = @api_client.cancel_batch(openai_batch_id)
          JobManager.update_from_openai(job_id, batch_status)
        else
          JobManager.update_status(job_id, JobManager::STATUS_CANCELLED)
        end
      end

      # List all jobs
      # @param status [String, nil] Filter by status
      # @return [Array<Hash>] Array of job metadata
      def list_jobs(status: nil)
        JobManager.list(status: status)
      end

      # Delete a job (local metadata only)
      # @param job_id [String] The job ID
      # @return [Boolean] True if deleted
      def delete_job(job_id)
        JobManager.delete(job_id)
      end

      private

      def build_jsonl(records, config)
        FileUtils.mkdir_p(TEMP_DIR)

        # GPT-5 series only - always use Responses API
        builder = JsonlBuilder.new(api_type: :responses)
        builder.add_records(records, config: config)

        jsonl_path = File.join(TEMP_DIR, "#{@job["job_id"]}.jsonl")
        builder.write(jsonl_path)
        jsonl_path
      end

      def build_mapping(records)
        mapping = {}
        records.each_with_index do |record, index|
          mapping[record[:id]] = {
            "index" => index,
            "source" => record[:source]
          }
        end
        mapping
      end

      def determine_endpoint(model)
        # GPT-5 series only - always use Responses API
        "/v1/responses"
      end

      def validate_model(model)
        unless model&.start_with?("gpt-5")
          raise ArgumentError, "Only GPT-5 series models are supported for batch processing. Got: #{model}"
        end
      end
    end
  end
end
