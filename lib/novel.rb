# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Novel < App
    DESC = "Interactive Story Plot Generator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, research_mode: false)
      @num_retained_turns = 2
      params = {
        "temperature" => 0.3,
        "top_p" => 1.0,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1,
        "model" => OpenAI.model_name(research_mode: research_mode),
        "max_tokens" => 1000,
        "stream" => true,
        "stop" => nil
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["novel"]
                 when "chat/completions"
                   TEMPLATES["chat_novel"]
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
                if res.size > @num_retained_turns * 2 + 1
                  res.delete_at 1
                  res.delete_at 1
                end
                res
              end
            end
           )
      @completion = openai_completion
    end
  end
end
