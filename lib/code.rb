# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Code < App
    DESC = "Interactive Program Code Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
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
            {},
            "conversation_history",
            "response",
            proc do |res|
              conv.shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 2000
      @completion = openai_completion
    end
  end
end
