# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Code < App
    DESC = "Interactive Program Code Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, research_mode: false)
      params = {
        "temperature" => 0.0,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0,
        "model" => OpenAI.model_name(research_mode: research_mode),
        "max_tokens" => 1000,
        "stream" => true,
        "stop" => nil
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["code"]
                 when "chat/completions"
                   TEMPLATES["chat_code"]
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
