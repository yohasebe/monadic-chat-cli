# frozen_string_literal: false

require "http"
require "oj"
require "net/http"
require "uri"
require "strscan"
require "tty-progressbar"
require_relative "model_specs"

Oj.mimic_JSON

OPEN_TIMEOUT = 10
RETRY_MAX_COUNT = 10
RETRY_WAIT_TIME_SEC = 1

module OpenAI
  # Build HTTP client with standard headers
  # @param access_token [String] API access token
  # @param streaming [Boolean] Whether to accept streaming responses
  # @return [HTTP::Client] Configured HTTP client
  def self.build_http_client(access_token, streaming: false)
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }
    headers["Accept"] = "text/event-stream" if streaming
    HTTP.headers(headers)
  end

  # Standard timeout settings
  # @param timeout_sec [Integer] Read/write timeout in seconds
  # @return [Hash] Timeout settings hash
  def self.timeout_settings(timeout_sec)
    {
      connect: OPEN_TIMEOUT,
      write: timeout_sec,
      read: timeout_sec
    }
  end

  # Execute block with retry logic for HTTP errors
  # @param max_retries [Integer] Maximum retry attempts
  # @param wait_time [Integer] Wait time between retries in seconds
  # @yield Block to execute
  # @return Result of block or error hash
  def self.with_retry(max_retries: RETRY_MAX_COUNT, wait_time: RETRY_WAIT_TIME_SEC, &block)
    retry_count = 0
    begin
      yield
    rescue HTTP::Error, HTTP::TimeoutError => e
      retry_count += 1
      if retry_count < max_retries
        sleep wait_time
        retry
      else
        { "type" => "error", "content" => "Error: #{e.class} - #{e.message}" }
      end
    end
  end
  # Legacy constant for backward compatibility with tests
  # Maps model name to api_type string
  AVAILABLE_MODELS = MODEL_SPECS.transform_values { |spec|
    spec["api_type"] || API_CHAT_COMPLETIONS
  }.freeze

  # Models that support both APIs (can use Chat Completions as fallback)
  # GPT-5 series supports both, but Responses API is preferred for better features
  DUAL_API_MODELS = MODEL_SPECS.select { |model, spec|
    model.start_with?("gpt-5") && spec["api_type"] == API_RESPONSES
  }.keys.freeze

  # Query method for Chat Completions API
  def self.query(access_token, mode, method, timeout_sec = 60, query = {}, &block)
    target_uri = "https://api.openai.com/v1/#{method}"
    http = build_http_client(access_token, streaming: query["stream"])
    timeouts = timeout_settings(timeout_sec)

    res = case mode
          when "post"
            http.timeout(timeouts).post(target_uri, json: query)
          when "get"
            http.timeout(timeouts).get(target_uri)
          end

    if query["stream"]
      json = nil
      buffer = ""

      res.body.each do |chunk|
        break if /\Rdata: \[DONE\]\R/ =~ chunk

        buffer << chunk
        scanner = StringScanner.new(buffer)
        pattern = /data: (\{.*?\})(?=\n|\z)/m
        until scanner.eos?
          matched = scanner.scan_until(pattern)
          if matched
            json_data = matched.match(pattern)[1]

            begin
              res = JSON.parse(json_data)
              choice = res.dig("choices", 0) || {}

              fragment = choice.dig("delta", "content").to_s
              next if !fragment || fragment == ""

              block&.call fragment

              json ||= res
              json["choices"][0]["text"] ||= +""
              json["choices"][0]["text"] << fragment

              if choice["finish_reason"] == "length" || choice["finish_reason"] == "stop"
                finish = { "type" => "message", "content" => "DONE" }
                block&.call finish
                break
              end
            rescue JSON::ParserError
              res = { "type" => "error", "content" => "Error: JSON Parsing" }
              block&.call res
              res
            end
          else
            buffer = scanner.rest
            break
          end
        end
      end
      json
    else
      begin
        JSON.parse res.body
      rescue JSON::ParserError
        res = { "type" => "error", "content" => "Error: JSON Parsing" }
        block&.call res
        res
      end
    end
  rescue HTTP::Error, HTTP::TimeoutError => e
    @retry_count ||= 0
    @retry_count += 1
    if @retry_count < RETRY_MAX_COUNT
      sleep RETRY_WAIT_TIME_SEC
      retry
    else
      @retry_count = 0
      res = { "type" => "error", "content" => "Error: #{e.class} - #{e.message}" }
      block&.call res
      res
    end
  end

  # Extract text from Responses API output array structure
  # @param output [Array] The output array from Responses API
  # @return [String] Concatenated text from all output_text items
  def self.extract_output_text(output)
    return "" unless output.is_a?(Array)

    texts = []
    output.each do |item|
      next unless item["type"] == "message" && item["content"]

      item["content"].each do |content|
        texts << content["text"] if content["type"] == "output_text"
      end
    end
    texts.join("")
  end

  # Build choices structure for compatibility with Chat Completions API format
  # @param parsed [Hash] The parsed response
  # @param output_text [String] The extracted output text
  # @return [Hash] The response with choices structure added
  def self.build_choices_response(parsed, output_text)
    parsed ||= {}
    parsed["output_text"] ||= output_text
    parsed["choices"] = [{
      "text" => output_text,
      "finish_reason" => parsed["status"] == "completed" ? "stop" : (parsed["status"] || "stop")
    }]
    parsed
  end

  # Query method for Responses API
  # Handles the different request/response format of the Responses API
  def self.query_responses(access_token, timeout_sec = 60, query = {}, &block)
    target_uri = "https://api.openai.com/v1/responses"
    http = build_http_client(access_token, streaming: query["stream"])
    timeouts = timeout_settings(timeout_sec)

    res = http.timeout(timeouts).post(target_uri, json: query)

    # Check response status
    unless res.status.success?
      error_body = res.body.to_s rescue "Unable to read body"
      begin
        error_json = JSON.parse(error_body)
        return { "error" => error_json["error"] }
      rescue JSON::ParserError
        return { "error" => { "message" => "API returned status #{res.status}: #{error_body}" } }
      end
    end

    if query["stream"]
      json = nil
      buffer = ""
      output_text = +""
      current_event = nil

      res.body.each do |chunk|
        buffer << chunk

        # Process complete lines
        while buffer.include?("\n")
          line, buffer = buffer.split("\n", 2)
          line = line.strip

          if line.start_with?("event:")
            current_event = line.sub("event:", "").strip
          elsif line.start_with?("data:")
            data_str = line.sub("data:", "").strip

            # Skip [DONE] marker
            next if data_str == "[DONE]"

            begin
              parsed = JSON.parse(data_str)

              # Handle based on event type or response structure
              if current_event == "response.output_text.delta" || parsed["type"] == "response.output_text.delta"
                fragment = parsed["delta"].to_s
                unless fragment.empty?
                  block&.call fragment
                  output_text << fragment
                end
              elsif current_event == "response.completed" || parsed["type"] == "response.completed"
                json = parsed["response"] || parsed
                finish = { "type" => "message", "content" => "DONE" }
                block&.call finish
              elsif current_event == "response.done" || parsed["type"] == "response.done"
                finish = { "type" => "message", "content" => "DONE" }
                block&.call finish
              elsif parsed["error"]
                error_res = { "type" => "error", "content" => "Error: #{parsed["error"]["message"]}" }
                block&.call error_res
                return { "error" => parsed["error"] }
              elsif parsed["output_text"]
                # Direct response with output_text
                json = parsed
              elsif parsed["output"]
                # Response with output array
                json = parsed
                output_text << extract_output_text(parsed["output"])
              end

              current_event = nil
            rescue JSON::ParserError
              # Incomplete JSON or invalid data, skip
            end
          elsif line.empty?
            current_event = nil
          end
        end
      end

      # Build final response structure compatible with existing code
      final_text = output_text.empty? ? json&.dig("output_text") : output_text
      (json || !output_text.empty?) ? build_choices_response(json, final_text) : json
    else
      begin
        parsed = JSON.parse(res.body)

        # Check for API error
        return { "error" => parsed["error"] } if parsed["error"]

        # Extract text from output array if present
        output_text = parsed["output_text"] || extract_output_text(parsed["output"])

        # Add choices structure for compatibility with existing code
        build_choices_response(parsed, output_text)
      rescue JSON::ParserError => e
        { "type" => "error", "content" => "Error: JSON Parsing - #{e.message}" }
      end
    end
  rescue HTTP::Error, HTTP::TimeoutError => e
    @retry_count ||= 0
    @retry_count += 1
    if @retry_count < RETRY_MAX_COUNT
      sleep RETRY_WAIT_TIME_SEC
      retry
    else
      @retry_count = 0
      { "type" => "error", "content" => "Error: #{e.class} - #{e.message}" }
    end
  end

  # Convert Chat Completions format to Responses API format
  # structured_output: optional hash with "format" key for JSON schema
  def self.convert_to_responses_format(params, structured_output: nil)
    model = params["model"]
    responses_params = {
      "model" => model
    }

    # Convert messages to input format
    if params["messages"]
      messages = params["messages"]

      # Extract system message as instructions
      system_msgs = messages.select { |m| m["role"] == "system" }
      # Convert user/assistant messages to input
      non_system_msgs = messages.reject { |m| m["role"] == "system" }

      if non_system_msgs.empty? && system_msgs.any?
        # Research mode: only system message with full template
        # Use the template as input directly (not as instructions)
        responses_params["input"] = system_msgs.map { |m| m["content"] }.join("\n")
      else
        # Normal mode: separate instructions and input
        if system_msgs.any?
          responses_params["instructions"] = system_msgs.map { |m| m["content"] }.join("\n")
        end

        if non_system_msgs.size == 1 && non_system_msgs[0]["role"] == "user"
          # Simple single user message - use string input
          responses_params["input"] = non_system_msgs[0]["content"]
        elsif non_system_msgs.any?
          # Multiple messages - use array input
          responses_params["input"] = non_system_msgs.map do |msg|
            {
              "role" => msg["role"],
              "content" => msg["content"]
            }
          end
        end
      end
    end

    # Copy over compatible parameters
    responses_params["stream"] = params["stream"] if params.key?("stream")
    responses_params["max_output_tokens"] = params["max_tokens"] if params.key?("max_tokens")

    # Only include temperature/top_p for models that support it
    if supports_temperature?(model)
      responses_params["temperature"] = params["temperature"] if params.key?("temperature")
      responses_params["top_p"] = params["top_p"] if params.key?("top_p")
    end

    # Set reasoning effort for reasoning models (GPT-5 series, o-series, etc.)
    # Uses the model's default reasoning effort from models.json
    # Can be overridden via params["reasoning_effort"]
    default_effort = default_reasoning_effort(model)
    if default_effort
      effort = params["reasoning_effort"] || default_effort
      responses_params["reasoning"] = { "effort" => effort }
    end

    # Build text parameter for Responses API
    # Can include: verbosity (low/medium/high) and/or format (structured output)
    text_params = {}

    # Add verbosity for models that support it (GPT-5 series)
    if supports_verbosity?(model)
      verbosity = params["verbosity"] || default_verbosity(model)
      text_params["verbosity"] = verbosity
    end

    # Add structured output format for Responses API
    # Format: { "format" => { "type" => "json_schema", "name" => "...", "schema" => {...}, "strict" => true } }
    if structured_output && structured_output["format"]
      text_params["format"] = structured_output["format"]
    end

    # Only add text parameter if there's something to include
    responses_params["text"] = text_params unless text_params.empty?

    responses_params
  end

  def self.models(access_token)
    res = query(access_token, "get", "models")
    res.fetch("data", []).sort_by { |m| -m["created"] }
  end

  class Completion
    attr_reader :access_token

    def initialize(access_token)
      @access_token = access_token
    end

    def models
      OpenAI.models(@access_token)
    end

    # Run a completion request, automatically selecting the appropriate API
    # based on the model (Responses API for GPT-5+, Chat Completions for older models)
    #
    # structured_output: optional structured output schema
    #   For Responses API: { "format" => { "type" => "json_schema", ... } }
    #   For Chat Completions API: { "type" => "json_schema", "json_schema" => { ... } }
    def run(params, research_mode: false, timeout_sec: 60, num_retrials: 1, force_chat_completions: false, structured_output: nil, &block)
      model = params["model"]
      method = OpenAI.model_to_method(model, force_chat_completions: force_chat_completions)

      response = if method == OpenAI::API_RESPONSES && !force_chat_completions
                   # Use Responses API for GPT-5+ models
                   responses_params = OpenAI.convert_to_responses_format(params, structured_output: structured_output)
                   OpenAI.query_responses(@access_token, timeout_sec, responses_params, &block)
                 else
                   # Use Chat Completions API for older models or when forced
                   # Add structured output as response_format if provided
                   if structured_output && structured_output["json_schema"]
                     params = params.merge("response_format" => structured_output)
                   end
                   OpenAI.query(@access_token, "post", method, timeout_sec, params, &block)
                 end

      if response.nil?
        raise "No response received from API"
      elsif response["error"]
        error_msg = response["error"].is_a?(Hash) ? response["error"]["message"] : response["error"]
        raise error_msg
      elsif response.dig("choices", 0, "finish_reason") == "length"
        raise "finished because of length"
      end

      # Extract text from response - handle different response formats
      # Chat Completions API (non-streaming): choices[0].message.content
      # Chat Completions API (streaming): choices[0].text (built up by query method)
      # Responses API: choices[0].text (built up by query_responses method)
      text = response.dig("choices", 0, "text") ||
             response.dig("choices", 0, "message", "content")

      if research_mode
        # When using structured output, the response is already valid JSON
        # When not using structured output, parse JSON from text (legacy behavior)
        if structured_output
          parse_structured_json(text)
        else
          get_json(text)
        end
      else
        text
      end
    rescue StandardError => e
      case num_retrials
      when 0
        raise e
      else
        run(params, research_mode: research_mode, timeout_sec: timeout_sec, num_retrials: num_retrials - 1, force_chat_completions: force_chat_completions, structured_output: structured_output, &block)
      end
    end

    def get_json(data)
      case data
      when %r{<JSON>\n*(\{.+?\})\n*</JSON>}m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n").gsub(/\r\n/) { "\n" }
        res = JSON.parse(json)
      when /```json\s*(\{.+\})\s*```/m
        # Handle markdown code block format
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n").gsub(/\r\n/) { "\n" }
        res = JSON.parse(json)
      when /(\{.+\})/m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n").gsub(/\r\n/) { "\n" }
        res = JSON.parse(json)
      else
        res = data
      end
      res
    end

    # Parse structured output JSON
    # With structured output, the response is guaranteed to be valid JSON
    def parse_structured_json(data)
      return data if data.is_a?(Hash)

      json_str = data.to_s.strip
      # Remove any wrapper if present (shouldn't happen with structured output, but just in case)
      json_str = json_str.sub(/\A<JSON>\n?/, "").sub(/\n?<\/JSON>\z/, "")
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      # Fallback to legacy parsing if structured output somehow fails
      get_json(data)
    end

    def run_iteration(params, prompts, template, replace_key = "{{PROMPT}}", timeout_sec: 60, num_retrials: 0)
      bar = TTY::ProgressBar.new("[:bar] :current/:total :total_byte :percent ET::elapsed ETA::eta",
                                 total: prompts.size,
                                 bar_format: :box)
      bar.start
      json = ""
      prompts.each do |prompt|
        params["prompt"] = template.sub(replace_key, prompt)
        res = run(params, timeout_sec: timeout_sec, num_retrials: num_retrials)
        json = JSON.pretty_generate(get_json(res))
        bar.advance(1)
        template = template.sub(/JSON:\n+```json.+?```\n\n/m, "JSON:\n\n```json\n#{json}\n```\n\n")
      end
      bar.finish
      JSON.parse(json)
    end
  end
end
