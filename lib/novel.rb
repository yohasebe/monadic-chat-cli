# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Novel < App
    DESC = "Interactive Story Plot Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.4,
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
            {},
            "novel",
            "paragraph",
            proc do |res|
              res["novel"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 1000
      @completion = openai_completion
    end
  end
end
