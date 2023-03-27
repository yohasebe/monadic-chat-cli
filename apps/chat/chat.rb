# frozen_string_literal: true

require_relative "../../lib/monadic_app"

class Chat < MonadicApp
  DESC = "Natural Language Chat Agent"
  COLOR = "green"

  attr_accessor :template, :config, :params, :completion

  def initialize(openai_completion, research_mode: false, stream: true, params: {})
    @num_retained_turns = 10
    params = {
      "temperature" => 0.3,
      "top_p" => 1.0,
      "presence_penalty" => 0.2,
      "frequency_penalty" => 0.2,
      "model" => openai_completion.model_name(research_mode: research_mode),
      "max_tokens" => 1000,
      "stream" => stream,
      "stop" => nil
    }.merge(params)
    mode = research_mode ? :research : :normal
    template_json = TEMPLATES["normal/chat"]
    template_md = TEMPLATES["research/chat"]
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
              template_tokens = count_tokens(@template)
              conditions = [
                @messages.size > 1,
                template_tokens > params["max_tokens"].to_i / 2
              ]

              if conditions.all?
                to_delete = []
                offset = template_tokens - params["max_tokens"].to_i / 2
                @messages.each_with_index do |ele, i|
                  break if offset <= 0

                  to_delete << i if ele["role"] != "system"
                  offset -= count_tokens(ele.to_json)
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
