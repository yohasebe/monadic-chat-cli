# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Novel < App
    DESC = "Interactive Story Plot Generator"

    attr_accessor :template, :config, :params

    def initialize
      @num_tokens_kept = 1000
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.5,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1
      }
      super(params,
            TEMPLATES["novel"],
            "novel",
            "text",
            proc do |res|
              if res["num_tokens"].to_i > @num_tokens_kept
                conv = res["plot"].split(/\n\n+/).map(&:strip)
                conv.shift(2)
                res["plot"] = conv.join("\n\n")
              end
              res
            end
           )
    end
  end
end
