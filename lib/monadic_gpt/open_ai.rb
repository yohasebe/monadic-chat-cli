# frozen_string_literal: true

require "oj"
require "net/http"
require "uri"
require "parallel"
require "tty-progressbar"

Oj.mimic_JSON

module OpenAI
  def self.query(access_token, mode, method, timeout_sec = 60, query = {})
    sleep 0.5
    target_uri = "https://api.openai.com/v1/#{method}"
    uri = URI.parse(target_uri)

    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{access_token}"
    }

    case mode
    when "post"
      req = Net::HTTP::Post.new(uri, headers)
      req.body = query.to_json
    else
      req = Net::HTTP::Get.new(uri, headers)
    end

    req_options = {
      use_ssl: uri.scheme == "https",
      read_timeout: timeout_sec
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(req)
    end
    JSON.parse response.body
  end

  def self.models(access_token)
    res = query(access_token, "get", "models")
    res.fetch("data", [])
  end

  class Completion
    def initialize(access_token)
      @access_token = access_token
    end

    def models
      OpenAI.models(@access_token)
    end

    def run(params)
      response = OpenAI.query(@access_token, "post", "completions", 60, params)
      if response["error"]
        raise response["error"]["message"]
      elsif response["choices"][0]["finish_reason"] == "length"
        raise "finished because of length"
      end

      response
    end

    def run_expecting_json(params, num_retry: 0)
      res = run(params)
      text = res["choices"][0]["text"]
      case text
      when %r{<JSON>\n*(\{.+\})\n*</JSON>}m
        json = Regexp.last_match(1).gsub(/\r\n?/, "\n")
        parsed = JSON.parse(json)
      else
        raise "valid json object not found"
      end
      parsed
    rescue StandardError => e
      # pp res
      # pp e
      # pp e.backtrace
      # print text
      case num_retry
      when 0
        raise e
      else
        sleep 1
        run_expecting_json(params, num_retry: num_retry - 1)
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
