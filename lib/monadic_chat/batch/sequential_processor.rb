# frozen_string_literal: true

require "tty-progressbar"
require_relative "input_parser"
require_relative "job_manager"

module MonadicChat
  module Batch
    # Sequential processor for monadic batch operations
    # Processes records one by one, passing previous results to subsequent requests
    class SequentialProcessor
      attr_reader :completion, :job

      # Accumulation modes for passing context between requests
      ACCUMULATION_MODES = %w[none append replace summary].freeze

      # @param completion [OpenAI::Completion] The completion instance
      def initialize(completion)
        @completion = completion
        @job = nil
      end

      # Start a sequential batch job
      # @param input_path [String] Path to input (file or folder)
      # @param config [Hash] Configuration options
      # @option config [String] :model Model to use
      # @option config [String] :system_prompt System prompt
      # @option config [Integer] :max_tokens Max tokens for response
      # @option config [String] :accumulation_mode How to pass context (none, append, replace, summary)
      # @option config [String] :accumulation_placeholder Placeholder for replace mode (default: {{PREVIOUS}})
      # @option config [Integer] :context_window How many previous results to include (default: 1)
      # @yield [Hash] Called after each record with progress info
      # @return [Hash] The job metadata with results
      def start(input_path:, config: {}, &block)
        # Validate model
        model = config[:model] || config["model"] || "gpt-5-mini"
        validate_model(model)

        # Parse input
        parser = InputParser.new(input_path)
        records = parser.parse

        raise ArgumentError, "No records found in input" if records.empty?

        # Set defaults
        accumulation_mode = config[:accumulation_mode] || "none"
        unless ACCUMULATION_MODES.include?(accumulation_mode)
          raise ArgumentError, "Invalid accumulation_mode: #{accumulation_mode}. Must be one of: #{ACCUMULATION_MODES.join(', ')}"
        end

        placeholder = config[:accumulation_placeholder] || "{{PREVIOUS}}"
        context_window = config[:context_window] || 1

        # Create job record
        @job = JobManager.create(
          input_path: parser.source_path,
          input_type: parser.source_type,
          record_count: records.size,
          config: config.merge(accumulation_mode: accumulation_mode),
          mode: :sequential
        )

        results = []
        previous_results = []

        begin
          records.each_with_index do |record, index|
            # Build prompt with accumulated context
            prompt = build_prompt(
              content: record[:content],
              previous_results: previous_results,
              accumulation_mode: accumulation_mode,
              placeholder: placeholder,
              context_window: context_window
            )

            # Build API parameters
            params = build_params(prompt, config)

            # Execute API call
            response_text = @completion.run(
              params,
              research_mode: false,
              timeout_sec: config[:timeout_sec] || 120,
              num_retrials: config[:num_retrials] || 2
            )

            # Store result
            result = {
              custom_id: record[:id],
              source: record[:source],
              index: index,
              text: response_text,
              error: nil
            }
            results << result
            previous_results << response_text

            # Keep only context_window results
            previous_results = previous_results.last(context_window) if previous_results.size > context_window

            # Update job progress
            @job = JobManager.update_status(@job["job_id"], "in_progress", {
              "stats" => {
                "completed" => index + 1,
                "failed" => 0,
                "total" => records.size
              }
            })

            # Yield progress
            block&.call({
              index: index,
              total: records.size,
              record: record,
              result: result
            })

          rescue StandardError => e
            # Record error but continue
            result = {
              custom_id: record[:id],
              source: record[:source],
              index: index,
              text: nil,
              error: e.message
            }
            results << result

            @job = JobManager.update_status(@job["job_id"], "in_progress", {
              "stats" => {
                "completed" => results.count { |r| r[:text] },
                "failed" => results.count { |r| r[:error] },
                "total" => records.size
              }
            })

            block&.call({
              index: index,
              total: records.size,
              record: record,
              result: result,
              error: e
            })
          end

          # Mark as completed
          @job = JobManager.update_status(@job["job_id"], JobManager::STATUS_COMPLETED, {
            "stats" => {
              "completed" => results.count { |r| r[:text] },
              "failed" => results.count { |r| r[:error] },
              "total" => records.size
            }
          })

          # Store results in job
          JobManager.set_results(@job["job_id"], results)

          @job["results"] = results
          @job

        rescue StandardError => e
          JobManager.update_status(@job["job_id"], JobManager::STATUS_FAILED, {
            "errors" => [{ "message" => e.message }]
          })
          raise
        end
      end

      # Get results for a completed sequential job
      # @param job_id [String] The job ID
      # @return [Array<Hash>] Array of results
      def retrieve_results(job_id)
        job = JobManager.load(job_id)
        raise ArgumentError, "Job not found: #{job_id}" unless job
        raise "Job is not a sequential job" unless job["mode"] == "sequential"

        JobManager.get_results(job_id) || []
      end

      private

      def validate_model(model)
        unless model&.start_with?("gpt-5")
          raise ArgumentError, "Only GPT-5 series models are supported. Got: #{model}"
        end
      end

      def build_prompt(content:, previous_results:, accumulation_mode:, placeholder:, context_window:)
        case accumulation_mode
        when "none"
          content
        when "append"
          if previous_results.empty?
            content
          else
            context = previous_results.last(context_window).join("\n\n---\n\n")
            "Previous results:\n#{context}\n\n---\n\nCurrent input:\n#{content}"
          end
        when "replace"
          if previous_results.empty?
            content.gsub(placeholder, "(No previous result)")
          else
            context = previous_results.last(context_window).join("\n\n")
            content.gsub(placeholder, context)
          end
        when "summary"
          # For summary mode, include a condensed version of all previous results
          if previous_results.empty?
            content
          else
            summary = previous_results.map.with_index { |r, i| "#{i + 1}. #{r[0, 200]}..." }.join("\n")
            "Summary of previous #{previous_results.size} results:\n#{summary}\n\n---\n\nCurrent input:\n#{content}"
          end
        else
          content
        end
      end

      def build_params(prompt, config)
        {
          "model" => config[:model] || config["model"] || "gpt-5-mini",
          "messages" => [
            config[:system_prompt] ? { "role" => "system", "content" => config[:system_prompt] } : nil,
            { "role" => "user", "content" => prompt }
          ].compact,
          "max_tokens" => config[:max_tokens] || config["max_tokens"] || 2000,
          "stream" => true
        }
      end
    end
  end
end
