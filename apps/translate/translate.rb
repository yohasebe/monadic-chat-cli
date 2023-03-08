# frozen_string_literal: true

require_relative "../../lib/app"

module MonadicChat
  class Translate < App
    DESC = "Interactive Multilingual Translator"
    COLOR = "yellow"

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
                # obj = objectify
                ############################################################
                # Research mode recuder defined here                       #
                # obj: old Hash object                                     #
                # res: new response Hash object to be modified             #
                ############################################################
                if res["messages"].size > 1 &&
                   res["tokens"].to_i > params["max_tokens"].to_i / 2
                  res["messages"].shift(1)
                  res["turns"] = res["turns"].to_i - 1
                end
                res
              when "chat/completions"
                if res.size > @num_retained_turns * 2 + 1
                  res.each_with_index do |ele, i|
                    if ele["role"] != "system"
                      res.delete_at i
                      break
                    end
                  end
                end
                res
              end
            end
           )
      @completion = openai_completion
    end
  end
end
