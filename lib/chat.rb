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
        "model" => "gpt-3.5-turbo",
        "max_tokens" => 1000,
        "stream" => true,
        "stop" => nil
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["chat"]
                 when "chat/completions"
                   TEMPLATES["chat_chat"]
                 end
      super(params,
            template,
            {},
            "conversation_history",
            "response",
            proc do |res|
              case method
              when "completions"
                if res["conversation_history"].size > 1 && res["num_tokens"].to_i > params["max_tokens"].to_i / 2
                  res["conversation_history"].shift(1)
                  res["num_turns"] = res["num_turns"].to_i - 1
                end
                res
              when "chat/completions"
                res
              end
            end
           )
      @completion = openai_completion
    end
  end
end
