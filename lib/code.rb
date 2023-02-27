# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Code < App
    DESC = "Interactive Program Code Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
      params = {
        "temperature" => 0.0,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0
      }
      super(params,
            TEMPLATES["code"],
            {},
            "conversation_history",
            "response",
            proc do |res|
              res["conversation_history"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 2000
      @completion = openai_completion
    end
  end
end
