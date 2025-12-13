# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for parameter setting
  ##################################################

  def change_parameter
    # Check if current model supports reasoning_effort and verbosity
    model = @params["model"]
    reasoning_available = OpenAI.reasoning_model?(model)
    verbosity_available = OpenAI.supports_verbosity?(model)
    current_effort = @params["reasoning_effort"] || OpenAI.default_reasoning_effort(model)
    current_verbosity = @params["verbosity"] || OpenAI.default_verbosity(model)

    parameter = PROMPT_SYSTEM.select("Select the parameter to be set:", per_page: 10, cycle: true, show_help: :never, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      menu.choice "#{BULLET} model: #{@params["model"]}", "model"
      menu.choice "#{BULLET} max_tokens: #{@params["max_tokens"]}", "max_tokens"
      if reasoning_available
        menu.choice "#{BULLET} reasoning_effort: #{current_effort}", "reasoning_effort"
      else
        menu.choice "#{BULLET} temperature: #{@params["temperature"]}", "temperature"
        menu.choice "#{BULLET} top_p: #{@params["top_p"]}", "top_p"
      end
      if verbosity_available
        menu.choice "#{BULLET} verbosity: #{current_verbosity}", "verbosity"
      end
    end
    return if parameter == "cancel"

    case parameter
    when "model"
      value = change_model
      @method = OpenAI.model_to_method(value) if value
    when "max_tokens"
      value = change_max_tokens
    when "reasoning_effort"
      value = change_reasoning_effort
    when "verbosity"
      value = change_verbosity
    when "temperature"
      value = change_temperature
    when "top_p"
      value = change_top_p
    end
    @params[parameter] = value if value
    print "Parameter #{parameter} has been set to #{PASTEL.green(value)}\n" if value
  end

  def change_max_tokens
    PROMPT_SYSTEM.ask("Set value of max tokens [1000 to 16000]:", convert: :int) do |q|
      q.in "1000-16000"
      q.messages[:range?] = "Value out of expected range [1000 to 16000]"
    end
  end

  def change_reasoning_effort
    model = @params["model"]
    available = OpenAI.available_reasoning_efforts(model)
    current = @params["reasoning_effort"] || OpenAI.default_reasoning_effort(model)

    unless available
      print PASTEL.red("This model does not support reasoning_effort\n")
      return nil
    end

    effort = PROMPT_SYSTEM.select("Select reasoning effort:", per_page: 6, cycle: true, show_help: :never, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      available.each do |e|
        label = e == current ? "#{e} (current)" : e
        menu.choice "#{BULLET} #{label}", e
      end
    end
    return nil if effort == "cancel"

    effort
  end

  def change_verbosity
    model = @params["model"]
    available = OpenAI.available_verbosities(model)

    unless available
      print PASTEL.red("This model does not support verbosity\n")
      return nil
    end

    # If only one option is available, inform the user
    if available.size == 1
      print PASTEL.yellow("This model only supports verbosity: #{available[0]}\n")
      return nil
    end

    current = @params["verbosity"] || OpenAI.default_verbosity(model)

    verbosity = PROMPT_SYSTEM.select("Select verbosity level:", per_page: 6, cycle: true, show_help: :never, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      available.each do |v|
        label = v == current ? "#{v} (current)" : v
        menu.choice "#{BULLET} #{label}", v
      end
    end
    return nil if verbosity == "cancel"

    verbosity
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


  def change_model
    model = PROMPT_SYSTEM.select("Select a model:", per_page: 12, cycle: false, show_help: :never, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      TTY::Cursor.save
      SPINNER.auto_spin
      api_models = @completion.models
      SPINNER.stop
      TTY::Cursor.restore

      # Filter to only GPT-5 series models
      supported_models = api_models
        .select { |m| OpenAI.model_available?(m["id"]) && m["id"].start_with?("gpt-5") }

      # Sort: gpt-5.2 first, then gpt-5.1, then gpt-5, by creation date
      sorted_models = supported_models.sort_by do |m|
        priority = case m["id"]
                   when /^gpt-5\.2/ then 0
                   when /^gpt-5\.1/ then 1
                   when /^gpt-5/ then 2
                   else 3
                   end
        [priority, -m["created"]]
      end

      sorted_models.each { |m| menu.choice "#{BULLET} #{m["id"]}", m["id"] }
    end
    return nil if model == "cancel"

    # Check if the selected model is expensive and requires confirmation
    if OpenAI.expensive_model?(model)
      print "\n"
      print PASTEL.bold.red(OpenAI.expensive_model_warning(model))
      print "\n"
      confirmed = PROMPT_SYSTEM.yes?("Are you sure you want to use this expensive model?", default: false)
      unless confirmed
        print PASTEL.yellow("Model selection cancelled.\n")
        return nil
      end
    end

    model
  end

  def show_params
    params_md = "# Current Parameter Values\n\n"
    @params.each do |key, val|
      next if /\A(?:prompt|stream|logprobs|echo|stop)\z/ =~ key

      params_md += "- #{key}: #{val}\n"
    end
    print PROMPT_SYSTEM.prefix, "\n"
    print "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
  end
end
