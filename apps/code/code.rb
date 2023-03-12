# frozen_string_literal: true

require_relative "../../lib/monadic_app"

class Code < MonadicApp
  DESC = "Interactive Program Code Generator"
  COLOR = "blue"

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
                 TEMPLATES["research/code"]
               when "chat/completions"
                 TEMPLATES["normal/code"]
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
              # obj: old Hash object (uncomment a line above before use) #
              # res: new response Hash object to be modified             #
              ############################################################
              conditions = [
                res["messages"].size > 1,
                res["tokens"].to_i > params["max_tokens"].to_i / 2
              ]
              if conditions.all?
                res["messages"].shift(1)
                res["turns"] = res["turns"].to_i - 1
              end
              res
            when "chat/completions"
              # obj = objectify
              ############################################################
              # Normal mode recuder defined here                         #
              # obj: old Hash object (uncomment a line above before use) #
              # res: new response Hash object to be modified             #
              ############################################################
              conditions = [
                res.size > @num_retained_turns * 2 + 1
              ]
              if conditions.all?
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
