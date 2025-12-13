# frozen_string_literal: false

require "http"
require "oj"
require "net/http"
require "uri"
require "strscan"
require "tty-progressbar"

Oj.mimic_JSON

OPEN_TIMEOUT = 10
RETRY_MAX_COUNT = 10
RETRY_WAIT_TIME_SEC = 1

module OpenAI
  # API types
  API_CHAT_COMPLETIONS = "chat/completions"
  API_RESPONSES = "responses"

  # Default models for different modes
  # Updated: December 2025
  def self.default_model(research_mode: false)
    if research_mode
      "gpt-5"
    else # normal mode
      "gpt-5-mini"
    end
  end

  # Available models and their supported API endpoints
  # Models are mapped to their preferred API (Responses API for GPT-5+, Chat Completions for older)
  # GPT-5 series also supports Chat Completions as fallback
  AVAILABLE_MODELS = {
    # GPT-5.2 series (Responses API preferred, Chat Completions supported)
    "gpt-5.2" => API_RESPONSES,
    "gpt-5.2-mini" => API_RESPONSES,
    "gpt-5.2-nano" => API_RESPONSES,
    # GPT-5.1 series (Responses API preferred, Chat Completions supported)
    "gpt-5.1" => API_RESPONSES,
    "gpt-5.1-mini" => API_RESPONSES,
    "gpt-5.1-nano" => API_RESPONSES,
    # GPT-5 series (Responses API preferred, Chat Completions supported)
    "gpt-5" => API_RESPONSES,
    "gpt-5-mini" => API_RESPONSES,
    "gpt-5-nano" => API_RESPONSES,
    # GPT-4.1 series (Chat Completions)
    "gpt-4.1" => API_CHAT_COMPLETIONS,
    "gpt-4.1-mini" => API_CHAT_COMPLETIONS,
    "gpt-4.1-nano" => API_CHAT_COMPLETIONS,
    # GPT-4o series (Chat Completions)
    "gpt-4o" => API_CHAT_COMPLETIONS,
    "gpt-4o-mini" => API_CHAT_COMPLETIONS,
    "gpt-4o-2024-11-20" => API_CHAT_COMPLETIONS,
    # GPT-4 Turbo (legacy but still available)
    "gpt-4-turbo" => API_CHAT_COMPLETIONS
  }.freeze

  # Models that ONLY work with Responses API (no Chat Completions fallback)
  RESPONSES_API_ONLY_MODELS = %w[
    gpt-5-codex
    gpt-5.1-codex
    gpt-5.2-codex
  ].freeze

  # Models that support both APIs (can use Chat Completions as fallback)
  # GPT-5 series supports both, but Responses API is preferred for better features
  DUAL_API_MODELS = %w[
    gpt-5 gpt-5-mini gpt-5-nano
    gpt-5.1 gpt-5.1-mini gpt-5.1-nano
    gpt-5.2 gpt-5.2-mini gpt-5.2-nano
  ].freeze

  # Expensive models that require user confirmation before use
  # These models have significantly higher costs per token
  # Pattern matching is used to catch model variants (e.g., gpt-5-pro, gpt-5.2-pro)
  EXPENSIVE_MODEL_PATTERNS = [
    /\bgpt-5.*-pro\b/i,       # GPT-5 Pro variants (extremely expensive)
    /\bo3-pro\b/i,            # o3-pro (extremely expensive)
    /\bgpt-5-codex-max\b/i,   # GPT-5 Codex Max
    /\bo1-pro\b/i             # o1-pro
  ].freeze

  # Check if a model is expensive and requires confirmation
  def self.expensive_model?(model)
    EXPENSIVE_MODEL_PATTERNS.any? { |pattern| pattern.match?(model) }
  end

  # Get warning message for expensive models
  def self.expensive_model_warning(model)
    <<~WARNING
      ============================================================
      WARNING: High-cost model selected!

      Model: #{model}

      This model has significantly higher costs compared to
      standard models. A single conversation could cost $10-100+.

      Please ensure you understand the pricing before proceeding.
      ============================================================
    WARNING
  end

  # Check if a model uses Responses API
  def self.responses_api?(model)
    AVAILABLE_MODELS[model] == API_RESPONSES || RESPONSES_API_ONLY_MODELS.include?(model)
  end

  # Check if a model supports Chat Completions API (either primary or fallback)
  def self.chat_completions_api?(model)
    AVAILABLE_MODELS[model] == API_CHAT_COMPLETIONS || DUAL_API_MODELS.include?(model)
  end

  # Get the API method/endpoint for a model
  # Returns the preferred API, but can be overridden with force_chat_completions for dual-API models
  def self.model_to_method(model, force_chat_completions: false)
    res = AVAILABLE_MODELS[model]
    if res.nil?
      puts ""
      puts "============================================================="
      if RESPONSES_API_ONLY_MODELS.include?(model)
        puts "Model #{model} requires the Responses API."
        puts "Responses API is now supported in Monadic Chat CLI."
        puts "However, this specific model may not be available yet."
      else
        puts "Model #{model} not found."
        puts "Maybe you are trying to use a model not available any more."
        puts "Check your monadic_chat.conf and try again."
      end
      puts "============================================================="
      puts ""
      exit 1
    end

    # Allow forcing Chat Completions API for dual-API models
    if force_chat_completions && DUAL_API_MODELS.include?(model)
      return API_CHAT_COMPLETIONS
    end

    res
  end

  # Query method for Chat Completions API
  def self.query(access_token, mode, method, timeout_sec = 60, query = {}, &block)
    target_uri = "https://api.openai.com/v1/#{method}"
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }
    headers["Accept"] = "text/event-stream" if query["stream"]
    http = HTTP.headers(headers)

    timeout_settings = {
      connect: OPEN_TIMEOUT,
      write: timeout_sec,
      read: timeout_sec
    }

    case mode
    when "post"
      res = http.timeout(timeout_settings).post(target_uri, json: query)
    when "get"
      res = http.timeout(timeout_settings).get(target_uri)
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
              pp res
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
        pp res
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
      pp res
      block&.call res
      res
    end
  end

  # Query method for Responses API
  # Handles the different request/response format of the Responses API
  def self.query_responses(access_token, timeout_sec = 60, query = {}, &block)
    target_uri = "https://api.openai.com/v1/responses"
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }
    headers["Accept"] = "text/event-stream" if query["stream"]
    http = HTTP.headers(headers)

    timeout_settings = {
      connect: OPEN_TIMEOUT,
      write: timeout_sec,
      read: timeout_sec
    }

    res = http.timeout(timeout_settings).post(target_uri, json: query)

    if query["stream"]
      json = nil
      buffer = ""
      output_text = +""

      res.body.each do |chunk|
        buffer << chunk

        # Parse SSE events (Responses API uses event: and data: format)
        while (match = buffer.match(/(?:event: ([^\n]*)\n)?data: (\{.*?\})\n\n/m))
          event_type = match[1]
          json_data = match[2]
          buffer = match.post_match

          begin
            parsed = JSON.parse(json_data)

            # Handle different event types
            case event_type
            when "response.output_text.delta"
              # Streaming text delta
              fragment = parsed["delta"].to_s
              next if fragment.empty?

              block&.call fragment
              output_text << fragment
            when "response.done", nil
              # Final response or non-event data
              if parsed["output_text"]
                # Non-streaming or final response
                json = parsed
              elsif parsed["type"] == "response.done"
                finish = { "type" => "message", "content" => "DONE" }
                block&.call finish
              end
            when "response.created"
              # Response created event - initialize json
              json ||= parsed
            when "error"
              res = { "type" => "error", "content" => "Error: #{parsed["message"]}" }
              pp res
              block&.call res
              return res
            end
          rescue JSON::ParserError
            # Incomplete JSON, continue buffering
            buffer = match[0] + buffer
            break
          end
        end
      end

      # Build final response structure compatible with existing code
      if json
        json["output_text"] ||= output_text unless output_text.empty?
        # Create a choices-like structure for compatibility
        json["choices"] = [{
          "text" => json["output_text"] || output_text,
          "finish_reason" => json["status"] == "completed" ? "stop" : json["status"]
        }]
      end
      json
    else
      begin
        parsed = JSON.parse(res.body)
        # Add choices structure for compatibility with existing code
        if parsed["output_text"]
          parsed["choices"] = [{
            "text" => parsed["output_text"],
            "finish_reason" => parsed["status"] == "completed" ? "stop" : parsed["status"]
          }]
        end
        parsed
      rescue JSON::ParserError
        res = { "type" => "error", "content" => "Error: JSON Parsing" }
        pp res
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
      pp res
      block&.call res
      res
    end
  end

  # Convert Chat Completions format to Responses API format
  def self.convert_to_responses_format(params)
    responses_params = {
      "model" => params["model"]
    }

    # Convert messages to input format
    if params["messages"]
      messages = params["messages"]

      # Extract system message as instructions
      system_msgs = messages.select { |m| m["role"] == "system" }
      if system_msgs.any?
        responses_params["instructions"] = system_msgs.map { |m| m["content"] }.join("\n")
      end

      # Convert user/assistant messages to input
      non_system_msgs = messages.reject { |m| m["role"] == "system" }
      if non_system_msgs.size == 1 && non_system_msgs[0]["role"] == "user"
        # Simple single user message - use string input
        responses_params["input"] = non_system_msgs[0]["content"]
      else
        # Multiple messages - use array input
        responses_params["input"] = non_system_msgs.map do |msg|
          {
            "role" => msg["role"],
            "content" => msg["content"]
          }
        end
      end
    end

    # Copy over compatible parameters
    responses_params["stream"] = params["stream"] if params.key?("stream")
    responses_params["temperature"] = params["temperature"] if params.key?("temperature")
    responses_params["top_p"] = params["top_p"] if params.key?("top_p")
    responses_params["max_output_tokens"] = params["max_tokens"] if params.key?("max_tokens")

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
    def run(params, research_mode: false, timeout_sec: 60, num_retrials: 1, force_chat_completions: false, &block)
      model = params["model"]
      method = OpenAI.model_to_method(model, force_chat_completions: force_chat_completions)

      response = if method == OpenAI::API_RESPONSES && !force_chat_completions
                   # Use Responses API for GPT-5+ models
                   responses_params = OpenAI.convert_to_responses_format(params)
                   OpenAI.query_responses(@access_token, timeout_sec, responses_params, &block)
                 else
                   # Use Chat Completions API for older models or when forced
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

      text = response.dig("choices", 0, "text")
      if research_mode
        get_json text
      else
        text
      end
    rescue StandardError => e
      case num_retrials
      when 0
        raise e
      else
        run(params, research_mode: research_mode, timeout_sec: timeout_sec, num_retrials: num_retrials - 1, force_chat_completions: force_chat_completions, &block)
      end
    end

    def get_json(data)
      case data
      when %r{<JSON>\n*(\{.+?\})\n*</JSON>}m
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
