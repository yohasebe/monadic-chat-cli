# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Chat < App
    DESC = "Natural Language Chat Agent"

    attr_accessor :template, :config, :params

    def initialize
      @num_tokens_kept = 1000
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.3,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1
      }
      super(params,
            TEMPLATES["chat"],
            "conversation",
            "response",
            proc do |res|
              if !@started
                conv = res["conversation"].split("\n").map(&:strip)
                conv.shift(4)
                res["conversation"] = conv.join("\n")
              elsif res["num_tokens"].to_i > @num_tokens_kept
                conv = res["conversation"].split("\n").map(&:strip)
                conv.shift(2)
                res["conversation"] = conv.join("\n")
              end
              res
            end
           )
    end
  end
end
