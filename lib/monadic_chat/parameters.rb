# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for parameter setting
  ##################################################

  # Helper: Ask for numeric value with range validation
  # @param prompt [String] The prompt message
  # @param min [Numeric] Minimum value
  # @param max [Numeric] Maximum value
  # @param type [Symbol] :int or :float
  # @return [Numeric, nil] The entered value or nil if cancelled
  def ask_numeric_value(prompt, min:, max:, type: :int)
    PROMPT_SYSTEM.ask(prompt, convert: type) do |q|
      q.in "#{min}-#{max}"
      q.messages[:range?] = "Value out of expected range [#{min} to #{max}]"
    end
  end

  # Helper: Select from options with Cancel and current value highlight
  # @param prompt [String] The prompt message
  # @param options [Array<String>] Available options
  # @param current [String, nil] Current value to highlight
  # @return [String, nil] Selected value or nil if cancelled
  def select_from_options(prompt, options:, current: nil)
    return nil if options.nil? || options.empty?

    selected = PROMPT_SYSTEM.select(prompt, per_page: 6, cycle: true, show_help: :never, default: 1) do |menu|
      menu.choice "#{BULLET} Cancel", "cancel"
      options.each do |opt|
        label = (current && opt == current) ? "#{opt} (current)" : opt
        menu.choice "#{BULLET} #{label}", opt
      end
    end
    selected == "cancel" ? nil : selected
  end

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
    ask_numeric_value("Set value of max tokens [1000 to 16000]:", min: 1000, max: 16000, type: :int)
  end

  def change_reasoning_effort
    model = @params["model"]
    available = OpenAI.available_reasoning_efforts(model)

    unless available
      print PASTEL.red("This model does not support reasoning_effort\n")
      return nil
    end

    current = @params["reasoning_effort"] || OpenAI.default_reasoning_effort(model)
    select_from_options("Select reasoning effort:", options: available, current: current)
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
    select_from_options("Select verbosity level:", options: available, current: current)
  end

  def change_temperature
    ask_numeric_value("Set value of temperature [0.0 to 1.0]:", min: 0.0, max: 1.0, type: :float)
  end

  def change_top_p
    ask_numeric_value("Set value of top_p [0.0 to 1.0]:", min: 0.0, max: 1.0, type: :float)
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
