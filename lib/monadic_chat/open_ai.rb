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
  # Default models for different modes
  # Updated: December 2025
  def self.default_model(research_mode: false)
    if research_mode
      "gpt-4o"
    else # normal mode
      "gpt-4o-mini"
    end
  end

  # Available models for Chat Completions API
  # Note: gpt-5-codex requires Responses API only (not supported here yet)
  # For full GPT-5 features (chain-of-thought, etc.), consider using Responses API
  AVAILABLE_MODELS = {
    # GPT-5 series (supports both Chat Completions and Responses API)
    "gpt-5" => "chat/completions",
    "gpt-5-mini" => "chat/completions",
    "gpt-5-nano" => "chat/completions",
    # GPT-4.1 series
    "gpt-4.1" => "chat/completions",
    "gpt-4.1-mini" => "chat/completions",
    "gpt-4.1-nano" => "chat/completions",
    # GPT-4o series
    "gpt-4o" => "chat/completions",
    "gpt-4o-mini" => "chat/completions",
    "gpt-4o-2024-11-20" => "chat/completions",
    # GPT-4 Turbo (legacy but still available)
    "gpt-4-turbo" => "chat/completions"
  }.freeze

  # Models that require Responses API (not yet supported)
  # These models cannot be used with Chat Completions API
  RESPONSES_API_ONLY_MODELS = %w[
    gpt-5-codex
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

  def self.model_to_method(model)
    res = AVAILABLE_MODELS[model]
    if res.nil?
      puts ""
      puts "============================================================="
      if RESPONSES_API_ONLY_MODELS.include?(model)
        puts "Model #{model} requires the Responses API."
        puts "This model is not yet supported by Monadic Chat CLI."
        puts "Please use a different model (e.g., gpt-5, gpt-5-mini)."
      else
        puts "Model #{model} not found."
        puts "Maybe you are trying to use a model not available any more."
        puts "Check your monadic_chat.conf and try again."
      end
      puts "============================================================="
      puts ""
      exit 1
    end
    res
  end

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
        break if /\Rdata: [DONE]\R/ =~ chunk

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

    def run(params, research_mode: false, timeout_sec: 60, num_retrials: 1, &block)
      method = OpenAI.model_to_method(params["model"])

      response = OpenAI.query(@access_token, "post", method, timeout_sec, params, &block)

      if response["error"]
        raise response["error"]["message"]
      elsif response["choices"][0]["finish_reason"] == "length"
        raise "finished because of length"
      end

      if research_mode
        get_json response["choices"][0]["text"]
      else
        response["choices"][0]["text"]
      end
    rescue StandardError => e
      case num_retrials
      when 0
        raise e
      else
        run(params, research_mode: research_mode, timeout_sec: timeout_sec, num_retrials: num_retrials - 1, &block)
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
