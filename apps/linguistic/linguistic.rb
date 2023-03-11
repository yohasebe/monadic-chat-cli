# frozen_string_literal: true

require_relative "../../lib/app"

module MonadicChat
  class Linguistic < App
    DESC = "Natural Language Syntatic/Semantic/Pragmatic Analyzer"
    COLOR = "red"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, research_mode: false, stream: true)
      @num_retained_turns = 10
      params = {
        "temperature" => 0.0,
        "top_p" => 1.0,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0,
        "model" => OpenAI.model_name(research_mode: research_mode),
        "max_tokens" => 2000,
        "stream" => stream,
        "stop" => nil
      }
      method = OpenAI.model_to_method(params["model"])
      template = case method
                 when "completions"
                   TEMPLATES["research/linguistic"]
                 when "chat/completions"
                   TEMPLATES["normal/linguistic"]
                 end
      super(params,
            template,
            {},
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