# frozen_string_literal: true

require "http"
require "oj"
require "net/http"
require "uri"
require "strscan"
require "parallel"
require "tty-progressbar"

Oj.mimic_JSON

module OpenAI
  def self.model_name(research_mode: false)
    research_mode ? "text-davinci-002" : "gpt-3.5-turbo"
  end

  def self.model_to_method(model)
    {
      "text-davinci-003" => "completions",
      "gpt-3.5-turbo" => "chat/completions",
      "gpt-3.5-turbo-0301" => "chat/completions"
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
        chunk.split("\n\n").each do |data|
          content = data.strip[6..]
          break if content == "[DONE]"

          stream = JSON.parse(content)
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
        end
      end
      json
    else
      JSON.parse res.body
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

    def run(params, num_retry: 1, &block)
      method = OpenAI.model_to_method(params["model"])

      response = OpenAI.query(@access_token, "post", method, 60, params, &block)
      if response["error"]
        raise response["error"]["message"]
      elsif response["choices"][0]["finish_reason"] == "length"
        raise "finished because of length"
      end

      case method
      when "completions"
        get_json response ["choices"][0]["text"]
      when "chat/completions"
        response ["choices"][0]["text"]
      end
    rescue StandardError => e
      case num_retry
      when 0
        raise e
      else
        run(params, num_retry: num_retry - 1, &block)
      end
    end

    def get_json(data)
      case data
      when %r{<JSON>\n*(\{.+\})\n*</JSON>}m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n").gsub(/\r\n/) { "\n" }
        JSON.parse(json)
      when /(\{.+\})/m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n").gsub(/\r\n/) { "\n" }
        JSON.parse(json)
      else
        data
      end
    end

    def run_iteration(params, prompts, template, replace_key = "{{PROMPT}}", num_retry: 0)
      bar = TTY::ProgressBar.new("[:bar] :current/:total :total_byte :percent ET::elapsed ETA::eta",
                                 total: prompts.size,
                                 bar_format: :box)
      bar.start
      json = ""
      prompts.each do |prompt|
        params["prompt"] = template.sub(replace_key, prompt)
        res = run(params, num_retry: num_retry)
        json = JSON.pretty_generate(res)
        bar.advance(1)
        template = template.sub(/\n\n```json.+?```\n\n/m, "\n\n```json\n#{json}\n```\n\n")
      end
      bar.finish
      JSON.parse(json)
    end
  end
end
