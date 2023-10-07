# frozen_string_literal: true

require_relative "../../lib/monadic_app"

class Wikipedia < MonadicApp
  DESC = "Searches Wikipedia for you (experimental)"
  COLOR = "white"

  attr_accessor :template, :config, :params, :completion

  def initialize(openai_completion, research_mode: false, stream: true, params: {})
    @num_retained_turns = 5
    params = {
      "temperature" => 0.3,
      "top_p" => 1.0,
      "presence_penalty" => 0.2,
      "frequency_penalty" => 0.2,
      "model" => research_mode ? SETTINGS["research_model"] : SETTINGS["normal_model"],
      "max_tokens" => 1000,
      "stream" => stream,
      "stop" => nil
    }.merge(params)
    mode = research_mode ? :research : :normal
    template_json = TEMPLATES["normal/wikipedia"]
    template_md = TEMPLATES["research/wikipedia"]
    super(mode: mode,
          params: params,
          template_json: template_json,
          template_md: template_md,
          placeholders: {},
          prop_accumulator: "messages",
          prop_newdata: "response",
          update_proc: proc do
            case mode
            when :research
              ############################################################
              # Research mode reduder defined here                       #
              # @messages: messages to this point                        #
              # @metadata: currently available metdata sent from GPT     #
              ############################################################
              conditions = [
                @messages.size > 1,
                @messages.size > @num_retained_turns * 2 + 1
              ]

              if conditions.all?
                to_delete = []
                new_num_messages = @messages.size
                @messages.each_with_index do |ele, i|
                  if ele["role"] != "system"
                    to_delete << i
                    new_num_messages -= 1
                  end
                  break if new_num_messages <= @num_retained_turns * 2 + 1
                end
                @messages.delete_if.with_index { |_, i| to_delete.include? i }
              end
            when :normal
              ############################################################
              # Normal mode recuder defined here                         #
              # @messages: messages to this point                        #
              ############################################################
              conditions = [
                @messages.size > 1,
                @messages.size > @num_retained_turns * 2 + 1
              ]

              if conditions.all?
                to_delete = []
                new_num_messages = @messages.size
                @messages.each_with_index do |ele, i|
                  if ele["role"] != "system"
                    to_delete << i
                    new_num_messages -= 1
                  end
                  break if new_num_messages <= @num_retained_turns * 2 + 1
                end
                @messages.delete_if.with_index { |_, i| to_delete.include? i }
              end
            end
          end
         )
    @completion = openai_completion
  end
end
