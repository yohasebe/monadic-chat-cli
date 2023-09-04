# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for parametter setting
  ##################################################

  def change_parameter
    parameter = PROMPT_SYSTEM.select("Select the parmeter to be set:", per_page: 7, cycle: true, show_help: :never, filter: true, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      menu.choice "#{BULLET} model: #{@params["model"]}", "model"
      menu.choice "#{BULLET} max_tokens: #{@params["max_tokens"]}", "max_tokens"
      menu.choice "#{BULLET} temperature: #{@params["temperature"]}", "temperature"
      menu.choice "#{BULLET} top_p: #{@params["top_p"]}", "top_p"
      menu.choice "#{BULLET} frequency_penalty: #{@params["frequency_penalty"]}", "frequency_penalty"
      menu.choice "#{BULLET} presence_penalty: #{@params["presence_penalty"]}", "presence_penalty"
    end
    return if parameter == "cancel"

    case parameter
    when "model"
      value = change_model
      @method = OpenAI.model_to_method(value)
    when "max_tokens"
      value = change_max_tokens
    when "temperature"
      value = change_temperature
    when "top_p"
      value = change_top_p
    when "frequency_penalty"
      value = change_frequency_penalty
    when "presence_penalty"
      value = change_presence_penalty
    end
    @params[parameter] = value if value
    print "Parameter #{parameter} has been set to #{PASTEL.green(value)}\n" if value
  end

  def change_max_tokens
    PROMPT_SYSTEM.ask("Set value of max tokens [1000 to 8000]:", convert: :int) do |q|
      q.in "1000-8000"
      q.messages[:range?] = "Value out of expected range [1000 to 2048]"
    end
  end

  def change_temperature
    PROMPT_SYSTEM.ask("Set value of temperature [0.0 to 1.0]:", convert: :float) do |q|
      q.in "0.0-1.0"
      q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
    end
  end

  def change_top_p
    PROMPT_SYSTEM.ask("Set value of top_p [0.0 to 1.0]:", convert: :float) do |q|
      q.in "0.0-1.0"
      q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
    end
  end

  def change_frequency_penalty
    PROMPT_SYSTEM.ask("Set value of frequency penalty [-2.0 to 2.0]:", convert: :float) do |q|
      q.in "-2.0-2.0"
      q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
    end
  end

  def change_presence_penalty
    PROMPT_SYSTEM.ask("Set value of presence penalty [-2.0 to 2.0]:", convert: :float) do |q|
      q.in "-2.0-2.0"
      q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
    end
  end

  def change_model
    model = PROMPT_SYSTEM.select("Select a model:", per_page: 10, cycle: false, show_help: :never, filter: true, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      TTY::Cursor.save
      SPINNER.auto_spin
      models = @completion.models
      SPINNER.stop
      TTY::Cursor.restore
      case @mode
      when :research
        models.filter { |m| ["completions", "chat/completions"].include? OpenAI.model_to_method(m["id"]) }.sort_by { |m| -m["created"] }.each do |m|
          menu.choice "#{BULLET} #{m["id"]}", m["id"]
        end
      when :normal
        models.filter { |m| OpenAI.model_to_method(m["id"]) == "chat/completions" && OpenAI.model_to_method(m["id"]) }.sort_by { |m| -m["created"] }.each do |m|
          menu.choice "#{BULLET} #{m["id"]}", m["id"]
        end
      end
    end
    if model == "cancel"
      nil
    else
      model
    end
  end

  def show_params
    params_md = "# Current Parameter Values\n\n"
    @params.each do |key, val|
      next if /\A(?:prompt|stream|logprobs|echo|stop)\z/ =~ key

      params_md += "- #{key}: #{val}\n"
    end
    print prompt_system, "\n"
    print "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
  end
end
