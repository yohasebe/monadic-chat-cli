# frozen_string_literal: true

require_relative "monadic_chat"

module MonadicChat
  class Translate < App
    DESC = "Interactive Multilingual Translator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, replacements = nil)
      params = {
        "temperature" => 0.2,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0,
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "logprobs" => nil,
        "echo" => false,
        "stream" => true,
        "stop" => nil
      }
      replacements ||= {
        "mode" => :interactive,
        "{{TARGET_LANG}}" => "Input target language"
      }
      super(params,
            TEMPLATES["translate"],
            replacements,
            "translation_history",
            "translation",
            proc do |res|
              if res["translation_history"].size > 1 && res["num_tokens"].to_i > params["max_tokens"].to_i / 2
                res["translation_history"].shift(1)
                res["num_turns"] = res["num_turns"].to_i - 1
              end
              res
            end
           )
      @completion = openai_completion
    end
  end
end
