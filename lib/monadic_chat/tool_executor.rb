# frozen_string_literal: true

require "json"
require "fileutils"

class MonadicApp
  # Maximum file size for read operations (1MB)
  MAX_FILE_READ_SIZE = 1_048_576

  # Maximum file size for write operations (100KB)
  MAX_FILE_WRITE_SIZE = 102_400

  # Allowed directories for file operations (relative to home or absolute)
  ALLOWED_FILE_PATHS = [
    Dir.pwd,
    File.expand_path("~/Downloads"),
    File.expand_path("~/Documents"),
    File.expand_path("~/.monadic_chat")
  ].freeze

  ##################################################
  # Main tool execution entry point
  ##################################################

  # Execute a tool by name with given arguments
  # @param tool_name [String] Name of the tool to execute
  # @param arguments [Hash] Arguments for the tool
  # @return [String] Tool execution result (JSON or plain text)
  def execute_tool(tool_name, arguments)
    case tool_name
    # Search tools
    when "wikipedia_search"
      execute_wikipedia_search(arguments)
    when "web_search"
      execute_web_search(arguments)

    # Batch tools
    when "batch_list_profiles"
      execute_batch_list_profiles
    when "batch_check_path"
      execute_batch_check_path(arguments)
    when "batch_recent_jobs"
      execute_batch_recent_jobs(arguments)
    when "batch_start"
      execute_batch_start(arguments)
    when "batch_status"
      execute_batch_status(arguments)
    when "batch_result"
      execute_batch_result(arguments)
    when "batch_create_input_file"
      execute_batch_create_input_file(arguments)
    when "batch_save_profile"
      execute_batch_save_profile(arguments)

    # File tools
    when "file_read"
      execute_file_read(arguments)
    when "file_write"
      execute_file_write(arguments)
    when "file_list"
      execute_file_list(arguments)

    else
      JSON.generate({ "error" => "Unknown tool: #{tool_name}" })
    end
  rescue StandardError => e
    JSON.generate({ "error" => "Tool execution failed: #{e.message}" })
  end

  # Execute multiple tools (can be parallelized in the future)
  # @param tool_calls [Array<Hash>] Array of tool calls with id, function name, and arguments
  # @return [Array<Hash>] Array of tool results in message format
  def execute_tools_parallel(tool_calls)
    tool_calls.map do |tool_call|
      name = tool_call.dig("function", "name")
      args_str = tool_call.dig("function", "arguments") || "{}"
      args = args_str.is_a?(String) ? JSON.parse(args_str) : args_str

      result = execute_tool(name, args)

      {
        "tool_call_id" => tool_call["id"],
        "role" => "tool",
        "content" => result
      }
    end
  end

  ##################################################
  # Search tool implementations
  ##################################################

  def execute_wikipedia_search(arguments)
    query = arguments["query"]
    return JSON.generate({ "error" => "Query is required" }) unless query

    @wiki_search_cache ||= {}
    result = wikipedia_search(query, @wiki_search_cache)

    if result == "empty"
      JSON.generate({ "result" => "No Wikipedia results found for: #{query}" })
    else
      result # Already formatted as string
    end
  end

  def execute_web_search(arguments)
    query = arguments["query"]
    return JSON.generate({ "error" => "Query is required" }) unless query

    @web_search_cache ||= {}
    result = bing_search(query, @web_search_cache)

    if result == "empty"
      JSON.generate({ "result" => "No web search results found for: #{query}" })
    else
      result # Already formatted as string
    end
  end

  ##################################################
  # Batch tool implementations
  ##################################################

  def execute_batch_list_profiles
    profiles = MonadicChat::Batch::ProfileManager.list
    JSON.generate({
      "profiles" => profiles.map do |name, config|
        {
          "name" => name,
          "model" => config["model"],
          "max_tokens" => config["max_tokens"],
          "system_prompt" => config["system_prompt"]&.slice(0, 100)
        }
      end
    })
  end

  def execute_batch_check_path(arguments)
    path = arguments["path"]
    return JSON.generate({ "error" => "Path is required" }) unless path

    expanded = File.expand_path(path)
    result = {
      "path" => expanded,
      "exists" => File.exist?(expanded),
      "is_directory" => File.directory?(expanded),
      "is_file" => File.file?(expanded)
    }

    if File.exist?(expanded)
      if File.file?(expanded)
        result["size"] = File.size(expanded)
        result["extension"] = File.extname(expanded)
      elsif File.directory?(expanded)
        entries = Dir.entries(expanded).reject { |e| e.start_with?(".") }
        result["entry_count"] = entries.size
        result["sample_entries"] = entries.first(10)
      end
    end

    JSON.generate(result)
  end

  def execute_batch_recent_jobs(arguments)
    limit = arguments["limit"] || 5
    jobs = MonadicChat::Batch::JobManager.list.first(limit)

    JSON.generate({
      "jobs" => jobs.map do |job|
        {
          "job_id" => job["job_id"],
          "status" => job["status"],
          "mode" => job["mode"],
          "created_at" => job["created_at"],
          "progress" => "#{job.dig('stats', 'completed')}/#{job.dig('stats', 'total')}"
        }
      end
    })
  end

  def execute_batch_start(arguments)
    input_path = arguments["input_path"]
    return JSON.generate({ "error" => "input_path is required" }) unless input_path

    expanded_path = File.expand_path(input_path)
    unless File.exist?(expanded_path)
      return JSON.generate({ "error" => "Input path does not exist: #{expanded_path}" })
    end

    # Build config from arguments
    config = {}
    config[:model] = arguments["model"] if arguments["model"]
    config[:system_prompt] = arguments["system_prompt"] if arguments["system_prompt"]
    config[:accumulation_mode] = arguments["accumulation_mode"] if arguments["accumulation_mode"]

    mode = arguments["mode"] || "parallel"

    # Use the completion instance from the app
    if mode == "sequential"
      processor = MonadicChat::Batch::SequentialProcessor.new(@completion)
      job = processor.start(input_path: expanded_path, config: config)
    else
      processor = MonadicChat::Batch::Processor.new(@completion.access_token)
      job = processor.start(input_path: expanded_path, config: config)
    end

    JSON.generate({
      "success" => true,
      "job_id" => job["job_id"],
      "status" => job["status"],
      "mode" => job["mode"],
      "record_count" => job.dig("input", "record_count")
    })
  rescue StandardError => e
    JSON.generate({ "error" => "Failed to start batch job: #{e.message}" })
  end

  def execute_batch_status(arguments)
    job_id = arguments["job_id"]
    return JSON.generate({ "error" => "job_id is required" }) unless job_id

    job = MonadicChat::Batch::JobManager.load(job_id)
    return JSON.generate({ "error" => "Job not found: #{job_id}" }) unless job

    # For parallel jobs, try to update status from OpenAI
    if job["mode"] == "parallel" && job["openai_batch_id"]
      begin
        processor = MonadicChat::Batch::Processor.new(@completion.access_token)
        job = processor.check_status(job_id)
      rescue StandardError
        # Use cached status if API call fails
      end
    end

    JSON.generate({
      "job_id" => job["job_id"],
      "status" => job["status"],
      "mode" => job["mode"],
      "progress" => {
        "completed" => job.dig("stats", "completed"),
        "failed" => job.dig("stats", "failed"),
        "total" => job.dig("stats", "total")
      },
      "created_at" => job["created_at"],
      "updated_at" => job["updated_at"]
    })
  end

  def execute_batch_result(arguments)
    job_id = arguments["job_id"]
    return JSON.generate({ "error" => "job_id is required" }) unless job_id

    job = MonadicChat::Batch::JobManager.load(job_id)
    return JSON.generate({ "error" => "Job not found: #{job_id}" }) unless job

    unless job["status"] == "completed"
      return JSON.generate({
        "error" => "Job not completed yet",
        "status" => job["status"]
      })
    end

    format = arguments["format"] || "summary"

    # Get results based on mode
    results = if job["mode"] == "sequential"
                MonadicChat::Batch::JobManager.get_results(job_id) || []
              else
                processor = MonadicChat::Batch::Processor.new(@completion.access_token)
                processor.retrieve_results(job_id)
              end

    case format
    when "json"
      JSON.generate({ "results" => results })
    when "text"
      texts = results.map { |r| r[:text] || r["text"] }.compact
      JSON.generate({ "results" => texts })
    else # summary
      success_count = results.count { |r| (r[:text] || r["text"]) && !(r[:error] || r["error"]) }
      error_count = results.count { |r| r[:error] || r["error"] }
      sample = results.first(3).map do |r|
        {
          "id" => r[:custom_id] || r["custom_id"],
          "preview" => (r[:text] || r["text"])&.slice(0, 100)
        }
      end
      JSON.generate({
        "total" => results.size,
        "success" => success_count,
        "errors" => error_count,
        "sample" => sample
      })
    end
  end

  def execute_batch_create_input_file(arguments)
    prompts = arguments["prompts"]
    output_path = arguments["output_path"]

    return JSON.generate({ "error" => "prompts array is required" }) unless prompts.is_a?(Array)
    return JSON.generate({ "error" => "output_path is required" }) unless output_path

    expanded_path = File.expand_path(output_path)
    unless path_allowed?(expanded_path)
      return JSON.generate({ "error" => "Output path not allowed: #{expanded_path}" })
    end

    # Create directory if needed
    FileUtils.mkdir_p(File.dirname(expanded_path))

    # Write prompts to file (one per line)
    File.write(expanded_path, prompts.join("\n"))

    JSON.generate({
      "success" => true,
      "path" => expanded_path,
      "prompt_count" => prompts.size
    })
  end

  def execute_batch_save_profile(arguments)
    name = arguments["name"]
    return JSON.generate({ "error" => "name is required" }) unless name

    config = {}
    config["model"] = arguments["model"] if arguments["model"]
    config["system_prompt"] = arguments["system_prompt"] if arguments["system_prompt"]
    config["max_tokens"] = arguments["max_tokens"] if arguments["max_tokens"]

    if config.empty?
      return JSON.generate({ "error" => "At least one config option is required" })
    end

    MonadicChat::Batch::ProfileManager.save(name, config)

    JSON.generate({
      "success" => true,
      "name" => name,
      "config" => config
    })
  end

  ##################################################
  # File tool implementations (with security)
  ##################################################

  def execute_file_read(arguments)
    path = arguments["path"]
    return JSON.generate({ "error" => "path is required" }) unless path

    expanded_path = File.expand_path(path)
    unless path_allowed?(expanded_path)
      return JSON.generate({ "error" => "Path not allowed: #{expanded_path}" })
    end

    unless File.exist?(expanded_path)
      return JSON.generate({ "error" => "File not found: #{expanded_path}" })
    end

    unless File.file?(expanded_path)
      return JSON.generate({ "error" => "Not a file: #{expanded_path}" })
    end

    file_size = File.size(expanded_path)
    if file_size > MAX_FILE_READ_SIZE
      return JSON.generate({ "error" => "File too large (max #{MAX_FILE_READ_SIZE} bytes)" })
    end

    max_lines = arguments["max_lines"] || 100
    lines = File.readlines(expanded_path).first(max_lines)
    content = lines.join

    JSON.generate({
      "path" => expanded_path,
      "size" => file_size,
      "lines_read" => lines.size,
      "content" => content
    })
  end

  def execute_file_write(arguments)
    path = arguments["path"]
    content = arguments["content"]
    append = arguments["append"] || false

    return JSON.generate({ "error" => "path is required" }) unless path
    return JSON.generate({ "error" => "content is required" }) unless content

    expanded_path = File.expand_path(path)
    unless path_allowed?(expanded_path)
      return JSON.generate({ "error" => "Path not allowed: #{expanded_path}" })
    end

    if content.bytesize > MAX_FILE_WRITE_SIZE
      return JSON.generate({ "error" => "Content too large (max #{MAX_FILE_WRITE_SIZE} bytes)" })
    end

    # Create directory if needed
    FileUtils.mkdir_p(File.dirname(expanded_path))

    if append
      File.open(expanded_path, "a") { |f| f.write(content) }
    else
      File.write(expanded_path, content)
    end

    JSON.generate({
      "success" => true,
      "path" => expanded_path,
      "bytes_written" => content.bytesize,
      "mode" => append ? "append" : "overwrite"
    })
  end

  def execute_file_list(arguments)
    path = arguments["path"] || "."
    pattern = arguments["pattern"]

    expanded_path = File.expand_path(path)
    unless path_allowed?(expanded_path)
      return JSON.generate({ "error" => "Path not allowed: #{expanded_path}" })
    end

    unless File.directory?(expanded_path)
      return JSON.generate({ "error" => "Not a directory: #{expanded_path}" })
    end

    entries = if pattern
                Dir.glob(File.join(expanded_path, pattern))
              else
                Dir.entries(expanded_path).reject { |e| e.start_with?(".") }
                   .map { |e| File.join(expanded_path, e) }
              end

    files = entries.first(100).map do |entry|
      stat = File.stat(entry) rescue nil
      {
        "name" => File.basename(entry),
        "path" => entry,
        "type" => stat&.directory? ? "directory" : "file",
        "size" => stat&.file? ? stat.size : nil
      }
    end

    JSON.generate({
      "path" => expanded_path,
      "count" => files.size,
      "entries" => files
    })
  end

  private

  # Check if a path is within allowed directories
  # @param path [String] Absolute path to check
  # @return [Boolean] True if path is allowed
  def path_allowed?(path)
    # Prevent path traversal
    return false if path.include?("..")

    # Check if path starts with any allowed directory
    ALLOWED_FILE_PATHS.any? { |allowed| path.start_with?(allowed) }
  end
end
