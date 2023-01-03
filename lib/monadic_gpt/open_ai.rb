# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "parallel"
require "tty-progressbar"

module OpenAI
  def self.query(access_token, mode, method, timeout_sec = 60, query = {})
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

    def run(params)
      response = OpenAI.query(@access_token, "post", "completions", 60, params)
      if response["error"]
        raise response["error"]["message"]
      elsif response["choices"][0]["finish_reason"] == "length"
        raise "finished because of length"
      end

      response
    end

    def run_expecting_json(params, enable_retry: false)
      res = run(params)
      text = res["choices"][0].fetch("text", "").to_s
      case text
      when /```json\n(.+)\n`+(?:\n|\z)/m,
        /```\n(.+)\n`+(?:\n|\z)/m,
        /(\{.+\})/m
        parsed = JSON.parse(Regexp.last_match(1))
      when /(\{.+)/m
        parsed = JSON.parse("#{Regexp.last_match(1)}\n")
      else
        pp res
        pp text
        raise "valid json object not found"
      end
      parsed
    rescue StandardError => e
      raise e unless enable_retry

      sleep 2
      retry
    end

    def run_iteration(params, prompts)
      template = <<~TEMPLATE
        Set your response to the following prompt at the end of the value list of "responses" property of a JSON object in the structure shown blow. Then set the prompt at the end of the value list of the "prompts" property of the JSON object. \n
        Prompt: {{PROMPT}}\n
        ```json
        {
          "responses": [],
          "prompts": []
        }
        ```
      TEMPLATE

      bar = TTY::ProgressBar.new("[:bar] :current/:total :total_byte :percent ET::elapsed ETA::eta",
                                 total: prompts.size,
                                 bar_format: :box)
      bar.start
      json = ""
      prompts.each do |prompt|
        params["prompt"] = template.sub("{{PROMPT}}", prompt)
        res = run_expecting_json(params)
        json = JSON.pretty_generate(res)
        bar.advance(1)
        template = template.sub(/```json.+?```/m, "```json\n#{json}\n```")
      end
      bar.finish
      JSON.parse(json)
    end
  end
end
