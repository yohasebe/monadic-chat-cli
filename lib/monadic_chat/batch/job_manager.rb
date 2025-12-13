# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"
require "time"

module MonadicChat
  module Batch
    # Manages batch job metadata and persistence
    class JobManager
      BATCHES_DIR = File.expand_path("~/.monadic_chat/batches")

      # Job status constants
      STATUS_CREATED = "created"
      STATUS_UPLOADING = "uploading"
      STATUS_SUBMITTED = "submitted"
      STATUS_VALIDATING = "validating"
      STATUS_IN_PROGRESS = "in_progress"
      STATUS_FINALIZING = "finalizing"
      STATUS_COMPLETED = "completed"
      STATUS_FAILED = "failed"
      STATUS_EXPIRED = "expired"
      STATUS_CANCELLED = "cancelled"

      class << self
        # Ensure the batches directory exists
        def ensure_directory
          FileUtils.mkdir_p(BATCHES_DIR)
        end

        # Create a new job
        # @param input_path [String] Path to the input source
        # @param input_type [Symbol] Type of input (:text_file, :csv_file, :folder)
        # @param record_count [Integer] Number of records
        # @param config [Hash] Job configuration (model, system_prompt, etc.)
        # @param mode [Symbol] Processing mode (:parallel or :sequential)
        # @return [Hash] The job metadata
        def create(input_path:, input_type:, record_count:, config:, mode: :parallel)
          ensure_directory

          job_id = generate_job_id
          job = {
            "job_id" => job_id,
            "openai_batch_id" => nil,
            "status" => STATUS_CREATED,
            "mode" => mode.to_s,
            "created_at" => Time.now.utc.iso8601,
            "updated_at" => Time.now.utc.iso8601,
            "input" => {
              "path" => input_path,
              "type" => input_type.to_s,
              "record_count" => record_count
            },
            "config" => normalize_config(config),
            "files" => {
              "jsonl_path" => nil,
              "input_file_id" => nil,
              "output_file_id" => nil,
              "error_file_id" => nil
            },
            "custom_id_mapping" => {},
            "output" => {
              "path" => nil,
              "format" => nil
            },
            "stats" => {
              "total" => record_count,
              "completed" => 0,
              "failed" => 0
            },
            "errors" => []
          }

          save(job)
          job
        end

        # Load a job by ID
        # @param job_id [String] The job ID
        # @return [Hash, nil] The job metadata or nil if not found
        def load(job_id)
          path = job_path(job_id)
          return nil unless File.exist?(path)

          JSON.parse(File.read(path))
        end

        # Save a job
        # @param job [Hash] The job metadata
        def save(job)
          ensure_directory
          job["updated_at"] = Time.now.utc.iso8601
          File.write(job_path(job["job_id"]), JSON.pretty_generate(job))
        end

        # Update job status
        # @param job_id [String] The job ID
        # @param status [String] New status
        # @param extra [Hash] Additional fields to update
        # @return [Hash] The updated job
        def update_status(job_id, status, extra = {})
          job = load(job_id)
          raise "Job not found: #{job_id}" unless job

          job["status"] = status
          extra.each { |k, v| job[k.to_s] = v }
          save(job)
          job
        end

        # Update job stats (from OpenAI batch status)
        # @param job_id [String] The job ID
        # @param openai_status [Hash] Status response from OpenAI API
        # @return [Hash] The updated job
        def update_from_openai(job_id, openai_status)
          job = load(job_id)
          raise "Job not found: #{job_id}" unless job

          # Map OpenAI status to our status
          job["status"] = openai_status["status"]
          job["openai_batch_id"] ||= openai_status["id"]

          # Update stats
          if openai_status["request_counts"]
            job["stats"]["total"] = openai_status["request_counts"]["total"] || job["stats"]["total"]
            job["stats"]["completed"] = openai_status["request_counts"]["completed"] || 0
            job["stats"]["failed"] = openai_status["request_counts"]["failed"] || 0
          end

          # Update file IDs
          job["files"]["output_file_id"] = openai_status["output_file_id"] if openai_status["output_file_id"]
          job["files"]["error_file_id"] = openai_status["error_file_id"] if openai_status["error_file_id"]

          # Store errors if present
          if openai_status["errors"] && !openai_status["errors"].empty?
            job["errors"] = openai_status["errors"]
          end

          save(job)
          job
        end

        # Set custom_id mapping
        # @param job_id [String] The job ID
        # @param mapping [Hash] Mapping from custom_id to source info
        def set_mapping(job_id, mapping)
          job = load(job_id)
          raise "Job not found: #{job_id}" unless job

          job["custom_id_mapping"] = mapping
          save(job)
          job
        end

        # Set results for sequential jobs (stored in separate file)
        # @param job_id [String] The job ID
        # @param results [Array<Hash>] Array of result objects
        def set_results(job_id, results)
          ensure_directory
          results_path = File.join(BATCHES_DIR, "#{job_id}_results.json")
          File.write(results_path, JSON.pretty_generate(results))
        end

        # Get results for sequential jobs
        # @param job_id [String] The job ID
        # @return [Array<Hash>, nil] Array of results or nil if not found
        def get_results(job_id)
          results_path = File.join(BATCHES_DIR, "#{job_id}_results.json")
          return nil unless File.exist?(results_path)

          JSON.parse(File.read(results_path), symbolize_names: true)
        rescue JSON::ParserError
          nil
        end

        # List all jobs
        # @param status [String, nil] Filter by status (optional)
        # @return [Array<Hash>] Array of job metadata
        def list(status: nil)
          ensure_directory
          jobs = Dir.glob(File.join(BATCHES_DIR, "batch_*.json")).map do |path|
            JSON.parse(File.read(path))
          rescue JSON::ParserError
            nil
          end.compact

          jobs = jobs.select { |j| j["status"] == status } if status
          jobs.sort_by { |j| j["created_at"] }.reverse
        end

        # Delete a job
        # @param job_id [String] The job ID
        # @return [Boolean] True if deleted, false if not found
        def delete(job_id)
          path = job_path(job_id)
          return false unless File.exist?(path)

          File.delete(path)
          true
        end

        # Check if a job exists
        # @param job_id [String] The job ID
        # @return [Boolean]
        def exists?(job_id)
          File.exist?(job_path(job_id))
        end

        private

        def generate_job_id
          "batch_#{Time.now.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4)}"
        end

        def job_path(job_id)
          File.join(BATCHES_DIR, "#{job_id}.json")
        end

        def normalize_config(config)
          # Convert symbol keys to strings
          config.transform_keys(&:to_s)
        end
      end
    end
  end
end
