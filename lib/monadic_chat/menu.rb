# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for showing menu and menu items
  ##################################################

  def show_menu
    clear_screen
    print TTY::Cursor.save
    parameter = PROMPT_SYSTEM.select("Select function:", per_page: 10, cycle: true, filter: true, default: 1, show_help: :never) do |menu|
      menu.choice "#{BULLET} #{PASTEL.bold("cancel/return/escape")}   cancel this menu", "cancel"
      menu.choice "#{BULLET} #{PASTEL.bold("params/settings/config")} show and change values of parameters", "params"
      menu.choice "#{BULLET} #{PASTEL.bold("data/context")}           show currrent contextual info", "data"
      menu.choice "#{BULLET} #{PASTEL.bold("html")}                   view contextual info on the web browser", "html"
      menu.choice "#{BULLET} #{PASTEL.bold("reset")}                  reset context to original state", "reset"
      menu.choice "#{BULLET} #{PASTEL.bold("save")}                   save current contextual info to file", "save"
      menu.choice "#{BULLET} #{PASTEL.bold("load")}                   load current contextual info from file", "load"
      menu.choice "#{BULLET} #{PASTEL.bold("clear/clean")}            clear screen", "clear"
      menu.choice "#{BULLET} #{PASTEL.bold("readme/documentation")}   open readme/documentation", "readme"
      menu.choice "#{BULLET} #{PASTEL.bold("exit/bye/quit")}          go back to main menu", "exit"
    end

    print TTY::Cursor.restore
    print TTY::Cursor.clear_screen_down
    print TTY::Cursor.restore

    case parameter
    when "cancel"
      return true
    when "params"
      change_parameter
    when "data"
      show_data
    when "html"
      set_html
    when "reset"
      reset
    when "save"
      save_data
    when "load"
      load_data
    when "clear"
      clear_screen
      print TTY::Cursor.clear_screen_down
    when "readme"
      MonadicChat.open_readme
    when "exit"
      return false
    end
    true
  end

  def reset
    @show_html = false
    @params = @params_original.dup

    case @method
    when "completions"
      @template = @template_original.dup
    when "chat/completions"
      @template = JSON.parse @template_original
    end

    if @placeholders.empty?
      print PROMPT_SYSTEM.prefix
      print "Context and parameters have been reset.\n"
    else
      fulfill_placeholders
    end
  end

  def ask_retrial(input, message = nil)
    print PROMPT_SYSTEM.prefix
    print " Error: #{message.capitalize}\n" if message
    retrial = PROMPT_USER.select("Do you want to try again?",
                                 show_help: :never) do |menu|
                                   menu.choice "Yes", "yes"
                                   menu.choice "No", "no"
                                   menu.choice "Show current contextual data", "show"
                                 end
    case retrial
    when "yes"
      input
    when "no"
      user_input
    when "show"
      show_data
      ask_retrial(input)
    end
  end

  def check_file(path)
    dirname = File.dirname(File.expand_path(path))
    path == "" || (/\.json\z/ =~ path.strip && Dir.exist?(dirname)) ? true : false
  end

  def save_data
    input = ""
    loop do
      print TTY::Cursor.save
      path = PROMPT_SYSTEM.readline("Enter the file path for the JSON file (including the file name and .json extension): ")
      if check_file(path)
        input = path
        break
      else
        print TTY::Cursor.restore
        print TTY::Cursor.clear_screen_down
      end
    end
    print TTY::Cursor.save

    return if input.to_s == ""

    filepath = File.expand_path(input.strip)

    if File.exist? filepath
      overwrite = PROMPT_SYSTEM.select("#{filepath} already exists.\nOverwrite?",
                                       show_help: :never) do |menu|
                                         menu.choice "Yes", "yes"
                                         menu.choice "No", "no"
                                       end
      return if overwrite == "no"
    end

    FileUtils.touch(filepath)
    unless File.exist? filepath
      print "File cannot be created\n"
      save_data
    end

    begin
      File.open(filepath, "w") do |f|
        case @method
        when "completions"
          m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
          f.write JSON.pretty_generate(JSON.parse(m[1]))
        when "chat/completions"
          f.write JSON.pretty_generate(@template)
        end

        print "Data has been saved successfully\n"
      end
      true
    rescue StandardError
      print "Error: Something went wrong"
      false
    end
  end

  def load_data
    input = ""
    loop do
      print TTY::Cursor.save
      path = PROMPT_SYSTEM.readline("Enter the file path for the JSON file (press Enter to cancel): ")
      if check_file(path)
        input = path
        break
      else
        print TTY::Cursor.restore
        print TTY::Cursor.clear_screen_down
      end
    end
    print TTY::Cursor.save

    return if input.to_s == ""

    begin
      filepath = File.expand_path(input.strip)
      json = File.read(filepath)
      data = JSON.parse(json)
      case @method
      when "completions"
        raise unless data["mode"] == self.class.name.downcase.split("::")[-1]

        new_template = @template.sub(/\n\n```json\s*\{.+\}\s*```\n\n/m, "\n\n```json\n#{JSON.pretty_generate(data).strip}\n```\n\n")
        @template = new_template
      when "chat/completions"
        raise unless data["messages"] && data["messages"][0]["role"]

        @template["messages"] = data["messages"]
      end
      print "Data has been loaded successfully\n"
      true
    rescue StandardError
      print "The data structure is not valid for this app\n"
      false
    end
  end

  ##################################################
  # methods for parameter setting
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
      case @method
      when "completions"
        @template = @template_original.dup
      when "chat/completions"
        @template = JSON.parse @template_original
      end
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
      print SPINNER
      models = @completion.models
      go_up_and_clear
      TTY::Cursor.restore
      TTY::Cursor.restore
      models.filter { |m| OpenAI.model_to_method(m["id"]) == @method }.sort_by { |m| -m["created"] }.each do |m|
        menu.choice "#{BULLET} #{m["id"]}", m["id"]
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
