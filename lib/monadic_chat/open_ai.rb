# frozen_string_literal: true

require "http"
require "oj"
require "net/http"
require "uri"
require "strscan"
require "tty-progressbar"

Oj.mimic_JSON

module OpenAI
  def self.default_model(research_mode: false)
    if research_mode
      "gpt-3.5-turbo-0613"
    else
      "gpt-3.5-turbo-0613"
    end
  end

  def self.model_to_method(model)
    {
      "gpt-3.5-turbo-instruct" => "completions",
      "gpt-4" => "chat/completions",
      "gpt-4-0613" => "chat/completions",
      "gpt-4-32K" => "chat/completions",
      "gpt-4-32k-0613" => "chat/completions",
      "gpt-3.5-turbo" => "chat/completions",
      "gpt-3.5-turbo-0613" => "chat/completions",
      "gpt-3.5-turbo-16k" => "chat/completions",
      "gpt-3.5-turbo-16k-0613" => "chat/completions"
    }[model]
  end

  def self.query(access_token, mode, method, timeout_sec = 60, query = {}, &block)
    target_uri = "https://api.openai.com/v1/#{method}"
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }
    headers["Accept"] = "text/event-stream" if query["stream"]
    http = HTTP.headers(headers)

    case mode
    when "post"
      res = http.timeout(timeout_sec).post(target_uri, json: query)
    when "get"
      res = http.timeout(timeout_sec).get(target_uri)
    end

    if query["stream"]
      json = nil
      res.body.each do |chunk|
        chunk.scan(/data: (\{.*\})/i).flatten.each do |data|
          content = data.strip
          break if content == "[DONE]"

          begin
            stream = JSON.parse(content)
          rescue JSON::ParserError
            next
          end

          fragment = case method
                     when "completions"
                       stream["choices"][0]["text"]
                     when "chat/completions"
                       stream["choices"][0]["delta"]["content"] || ""
                     end
          block&.call fragment
          if !json
            json = stream
          else
            case method
            when "completions"
              json["choices"][0]["text"] << fragment
            when "chat/completions"
              json["choices"][0]["text"] ||= +""
              json["choices"][0]["text"] << fragment
            end
          end
        rescue JSON::ParserError
          res = { "type" => "error", "content" => "Error: JSON Parsing" }
          pp res
          block&.call res
          res
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
