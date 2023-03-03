# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Translate < App
    DESC = "Interactive Multilingual Translator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, replacements: nil, research_mode: false)
      params = {
        "temperature" => 0.2,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0,
        "model" => OpenAI.model_name(research_mode: research_mode),
        "max_tokens" => 1000,
        "stream" => true,
        "stop" => nil
      }
      replacements ||= {
        "mode" => :interactive,
        "{{TARGET_LANG}}" => "Input target language"
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["translate"]
                 when "chat/completions"
                   TEMPLATES["chat_translate"]
                 end
      super(params,
            template,
            replacements,
            "translation_history",
            "translation",
            proc do |res|
              case method
              when "completions"
                if res["translation_history"].size > 1 && res["num_tokens"].to_i > params["max_tokens"].to_i / 2
                  res["translation_history"].shift(1)
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
