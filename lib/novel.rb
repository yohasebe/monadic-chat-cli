# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Novel < App
    DESC = "Interactive Story Plot Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.4,
        "top_p" => 1.0,
        "logprobs" => nil,
        "echo" => false,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1
      }
      super(params,
            TEMPLATES["novel"],
            {},
            "paragraphs",
            "new_paragraph",
            proc do |res|
              res["paragraphs"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 2000
      @completion = openai_completion
    end
  end
end
