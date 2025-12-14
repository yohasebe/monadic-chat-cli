# frozen_string_literal: true

require_relative "../../lib/monadic_app"
require_relative "../../lib/monadic_chat/batch"

class Batch < MonadicApp
  DESC = "Interactive Batch Processing Assistant"
  COLOR = "cyan"

  # Enable native tool use for batch processing
  # This allows the model to call batch and file tools directly
  enable_tools :batch, :file

  attr_accessor :template, :config, :params, :completion, :batch_config

  def initialize(openai_completion, research_mode: false, stream: true, params: {})
    @num_retained_turns = 10
    max_tokens = research_mode ? 8000 : 2000
    params = {
      "temperature" => 0.3,
      "top_p" => 1.0,
      "model" => research_mode ? SETTINGS["research_model"] : SETTINGS["normal_model"],
      "max_tokens" => max_tokens,
      "stream" => stream,
      "stop" => nil
    }.merge(params)
    mode = research_mode ? :research : :normal
    template_json = TEMPLATES["normal/batch"]
    template_md = TEMPLATES["research/batch"]
    super(mode: mode,
          params: params,
          template_json: template_json,
          template_md: template_md,
          placeholders: {},
          prop_accumulator: "messages",
          prop_newdata: "response",
          update_proc: proc do
            case mode
            when :research
              conditions = [
                @messages.size > 1,
                @messages.size > @num_retained_turns * 2 + 1
              ]

              if conditions.all?
                to_delete = []
                new_num_messages = @messages.size
                @messages.each_with_index do |ele, i|
                  if ele["role"] != "system"
                    to_delete << i
                    new_num_messages -= 1
                  end
                  break if new_num_messages <= @num_retained_turns * 2 + 1
                end
                @messages.delete_if.with_index { |_, i| to_delete.include? i }
              end
            when :normal
              conditions = [
                @messages.size > 1,
                @messages.size > @num_retained_turns * 2 + 1
              ]

              if conditions.all?
                to_delete = []
                new_num_messages = @messages.size
                @messages.each_with_index do |ele, i|
                  if ele["role"] != "system"
                    to_delete << i
                    new_num_messages -= 1
                  end
                  break if new_num_messages <= @num_retained_turns * 2 + 1
                end
                @messages.delete_if.with_index { |_, i| to_delete.include? i }
              end
            end
          end
         )
    @completion = openai_completion
    @batch_config = {}
  end

  # Execute a batch command and return the result
  # @param command [String] The batch subcommand to execute
  # @param args [Array<String>] Arguments for the command
  # @return [String] Result message
  def execute_batch_command(command, args = [])
    full_args = [command] + args
    # Capture output
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    begin
      MonadicChat::BatchCommands.run(full_args)
    ensure
      $stdout = original_stdout
    end

    captured_output.string
  end

  # List available batch profiles
  # @return [Array<String>] Profile names
  def list_profiles
    MonadicChat::Batch::ProfileManager.list.keys
  end

  # Check if an input path exists and get info
  # @param path [String] Input path
  # @return [Hash] Info about the path
  def check_input_path(path)
    expanded = File.expand_path(path)
    {
      exists: File.exist?(expanded),
      is_directory: File.directory?(expanded),
      is_file: File.file?(expanded),
      expanded_path: expanded
    }
  end

  # Get list of recent batch jobs
  # @param limit [Integer] Max jobs to return
  # @return [Array<Hash>] Recent jobs
  def recent_jobs(limit = 5)
    MonadicChat::Batch::JobManager.list.first(limit)
  end
end
