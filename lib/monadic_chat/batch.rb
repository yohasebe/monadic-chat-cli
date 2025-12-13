# frozen_string_literal: true

# Batch processing module for MonadicChat
# Provides functionality for processing large amounts of data using OpenAI Batch API

require_relative "batch/input_parser"
require_relative "batch/jsonl_builder"
require_relative "batch/job_manager"
require_relative "batch/api_client"
require_relative "batch/processor"
require_relative "batch/sequential_processor"
require_relative "batch/profile_manager"

module MonadicChat
  module Batch
    # Version of the batch processing module
    VERSION = "0.1.0"

    # Default configuration for batch processing
    DEFAULT_CONFIG = {
      "model" => "gpt-5-mini",
      "max_tokens" => 2000,
      "system_prompt" => nil
    }.freeze

    # Convenience method to create a new processor
    # @param access_token [String] OpenAI API access token
    # @return [Processor] A new batch processor instance
    def self.create_processor(access_token)
      Processor.new(access_token)
    end
  end
end
