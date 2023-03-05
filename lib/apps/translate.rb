# frozen_string_literal: true

require_relative "../app"

module MonadicChat
  class Translate < App
    DESC = "Interactive Multilingual Translator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, replacements: nil, research_mode: false, stream: true)
      @num_retained_turns = 10
      params = {
        "temperature" => 0.2,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0,
        "model" => OpenAI.model_name(research_mode: research_mode),
        "max_tokens" => 2000,
        "stream" => stream,
        "stop" => nil
      }
      replacements ||= {
        "mode" => :interactive,
        "{{TARGET_LANG}}" => "Input target language"
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["research/translate"]
                 when "chat/completions"
                   TEMPLATES["normal/translate"]
                 end
      super(params,
            template,
            replacements,
            "messages",
            "response",
            proc do |res|
              case method
              when "completions"
                if res["messages"].size > 1 && res["tokens"].to_i > params["max_tokens"].to_i / 2
                  res["messages"].shift(1)
                  res["turns"] = res["turns"].to_i - 1
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
