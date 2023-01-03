# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Code < App
    attr_accessor :template, :config, :params

    def initialize
      @num_tokens_kept = 1000
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.0,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0
      }
      super(params,
            TEMPLATES["code"],
            "conversation",
            "response",
            proc do |res|
              res["conversation"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
    end
  end
end
