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
        "model" => "text-davinci-003",
        "max_tokens" => 3000,
        "logprobs" => nil,
        "echo" => false,
        "stream" => true,
        "stop" => nil
      }
      super(params,
            TEMPLATES["code"],
            {},
            "conversation_history",
            "response",
            proc do |res|
              if res["conversation_history"].size > 1 && res["num_tokens"].to_i > params["max_tokens"].to_i / 2
                res["conversation_history"].shift(2)
                res["num_turns"] = res["num_turns"].to_i - 2
              end
              res
            end
           )
      @completion = openai_completion
    end
  end
end
