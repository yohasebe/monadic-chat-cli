# frozen_string_literal: true

require_relative "../../lib/monadic_app"

class Translate < MonadicApp
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
      "{{TARGET_LANG}}" => "Enter target language"
    }
    method = OpenAI.model_to_method(params["model"])
    case method
    when RESEARCH_MODE
      tjson = TEMPLATES["normal/translate"]
      tmarkdown = TEMPLATES["research/translate"]
    when NORMAL_MODE
      tjson = TEMPLATES["normal/translate"]
      tmarkdown = nil
    end
    super(params: params,
          tjson: tjson,
          tmarkdown: tmarkdown,
          placeholders: replacements,
          prop_accumulator: "messages",
          prop_newdata: "response",
          update_proc: proc do
            case method
            when RESEARCH_MODE
              ############################################################
              # Research mode reduder defined here                       #
              # @messages: messages to this point                        #
              # @metadata: currently available metdata sent from GPT     #
              ############################################################

              conditions = [
                @messages.size > 1,
                @metadata["tokens"].to_i > params["max_tokens"].to_i / 2
              ]

              @metadata["turns"] = @metadata["turns"].to_i - 1 if conditions.all?

            when NORMAL_MODE
              ############################################################
              # Normal mode recuder defined here                         #
              # @messages: messages to this point                        #
              ############################################################

              conditions = [
                @messages.size > @num_retained_turns * 2 + 1
              ]

              if conditions.all?
                @messages.each_with_index do |ele, i|
                  if ele["role"] != "system"
                    @messages.delete_at i
                    break
                  end
                end
              end
            end
          end
         )
    @completion = openai_completion
  end
end
