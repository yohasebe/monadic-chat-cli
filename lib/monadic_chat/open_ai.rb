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
      res = http.timeout(timeout_sec).get(target_uri, json: query)
    end

    if query["stream"]
      json = nil
      res.body.each do |chunk|
        chunk.split("\n\n").each do |data|
          content = data.strip[6..]
          break if content == "[DONE]"

          stream = JSON.parse(content)
          text = stream["choices"][0]["text"]
          block&.call text
          if !json
            json = stream
          else
            json["choices"][0]["text"] << text
          end
        end
      end
      json
    else
      JSON.parse res.body
    end
  end

  def self.models(access_token)
    query(access_token, "get", "models")
    # res.fetch("data", [])
  end

  class Completion
    def initialize(access_token)
      @access_token = access_token
    end

    def models
      OpenAI.models(@access_token)
    end

    def run(params, &block)
      response = OpenAI.query(@access_token, "post", "completions", 60, params, &block)
      if response["error"]
        raise response["error"]["message"]
      elsif response["choices"][0]["finish_reason"] == "length"
        raise "finished because of length"
      end

      response
    end

    def get_json(data)
      case data
      when %r{<JSON>\n*(\{.+\})\n*</JSON>}m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n")
        JSON.parse(json.gsub(/\r\n/) { "\n" })
      else
        raise "valid json object not found"
      end
    end

    def run_expecting_json(params, num_retry: 0, &block)
      res = run(params, &block)
      text = res["choices"][0]["text"]
      get_json text
    rescue StandardError => e
      case num_retry
      when 0
        raise e
      else
        # sleep 1
        run_expecting_json(params, num_retry: num_retry - 1, &block)
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
        res = run_expecting_json(params, num_retry: num_retry)
        json = JSON.pretty_generate(res)
        bar.advance(1)
        template = template.sub(/\n\n```json.+?```\n\n/m, "\n\n```json\n#{json}\n```\n\n")
      end
      bar.finish
      JSON.parse(json)
    end
  end
end
