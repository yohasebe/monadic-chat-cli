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
        "frequency_penalty" => 0.0,
        "max_tokens" => 2000
      }
      super(params,
            TEMPLATES["code"],
            {},
            "conversation_history",
            "response",
            proc do |res|
              res["conversation_history"].shift(1) if res["num_tokens"].to_i > params["max_tokens"] / 2
              res
            end
           )
      @completion = openai_completion
    end
  end
end
