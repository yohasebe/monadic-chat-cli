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
        "frequency_penalty" => 0.1,
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "logprobs" => nil,
        "echo" => false,
        "stream" => true,
        "stop" => nil
      }
      super(params,
            TEMPLATES["chat"],
            {},
            "conversation_history",
            "response",
            proc do |res|
              if res["conversation_history"].size > 1 && res["num_tokens"].to_i > params["max_tokens"].to_i / 2
                res["conversation_history"].shift(1)
                res["num_turns"] = res["num_turns"].to_i - 1
              end
              res
            end
           )
      @completion = openai_completion
    end
  end
end
