# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Chat < App
    DESC = "Natural Language Chat Agent"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
      params = {
        "temperature" => 0.3,
        "top_p" => 1.0,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1
      }
      super(params,
            TEMPLATES["chat"],
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
