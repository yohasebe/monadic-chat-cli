# frozen_string_literal: true

require "securerandom"

class MonadicApp
  ##################################################
  # methods for showing menu and menu items
  ##################################################

  def show_menu
    clear_screen
    print TTY::Cursor.save
    parameter = PROMPT_SYSTEM.select("Select function:", per_page: 10, cycle: true, filter: true, default: 1, show_help: :never) do |menu|
      menu.choice "#{BULLET} #{PASTEL.bold("cancel/return/escape")}    Cancel this menu", "cancel"
      menu.choice "#{BULLET} #{PASTEL.bold("params/settings/config")}  Show and change values of parameters", "params"
      menu.choice "#{BULLET} #{PASTEL.bold("data/context")}            Show currrent contextual info", "data"
      menu.choice "#{BULLET} #{PASTEL.bold("html")}                    View contextual info on the web browser", "html"
      menu.choice "#{BULLET} #{PASTEL.bold("reset")}                   Reset context to initial state", "reset"
      menu.choice "#{BULLET} #{PASTEL.bold("save")}                    Save current contextual info to file", "save"
      menu.choice "#{BULLET} #{PASTEL.bold("load")}                    Load current contextual info from file", "load"
      menu.choice "#{BULLET} #{PASTEL.bold("clear/clean")}             Clear screen", "clear"
      menu.choice "#{BULLET} #{PASTEL.bold("readme/documentation")}    Open readme/documentation", "readme"
      menu.choice "#{BULLET} #{PASTEL.bold("exit/bye/quit")}           Go back to main menu", "exit"
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
      @html = true
      show_html
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
    @html = false
    @params = @params_initial.dup
    @messages = @messages_initial.dup
    @template = @template_initial.dup
    @template_tokens = 0

    if @placeholders.empty?
      print PROMPT_SYSTEM.prefix
      print "Context and parameters have been reset.\n"
    else
      fulfill_placeholders
    end
  end

  def ask_retrial(input, message = nil)
    print PROMPT_SYSTEM.prefix
    print "Error: #{message.capitalize}\n" if message
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
        # Convert messages to Monadic Chat format (using 'text' instead of 'content')
        formatted_messages = @messages.map do |msg|
          {
            "role" => msg["role"],
            "text" => msg["content"] || msg["text"],
            "mid" => msg["mid"] || SecureRandom.hex(4)
          }
        end

        # Build export data in Monadic Chat format
        export_data = {
          "parameters" => {
            "app_name" => self.class.name,
            "model" => @params["model"],
            "temperature" => @params["temperature"],
            "max_tokens" => @params["max_tokens"],
            "mode" => @mode.to_s
          },
          "messages" => formatted_messages
        }

        # For research mode, also include template data
        if @mode == :research
          m = /JSON:\n+```json\s*(\{.+\})\s*```\n\n/m.match(@template)
          if m
            template_data = JSON.parse(m[1])
            export_data["parameters"].merge!(template_data.reject { |k, _| k == "messages" })
          end
        end

        f.write JSON.pretty_generate(export_data)
        print "Data has been saved successfully (Monadic Chat format)\n"
      end
      true
    rescue StandardError => e
      print "Error: #{e.message}\n"
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

      # Support both Monadic Chat format and legacy format
      messages = if data["messages"]
                   data["messages"]
                 elsif data["parameters"] && data["messages"]
                   data["messages"]
                 else
                   raise "Invalid format: no messages found"
                 end

      # Convert messages from Monadic Chat format ('text') to CLI format ('content')
      @messages = messages.map do |msg|
        {
          "role" => msg["role"],
          "content" => msg["text"] || msg["content"],
          "mid" => msg["mid"] || SecureRandom.hex(4)
        }
      end

      # Validate messages
      raise "Invalid messages structure" unless @messages.first && @messages.first["role"]

      # Handle research mode template updates
      if @mode == :research && data["parameters"]
        params_for_template = data["parameters"].reject { |k, _| %w[app_name messages].include?(k) }
        unless params_for_template.empty?
          @template = @template.sub(
            /JSON:\n+```json\s*\{.+\}\s*```\n\n/m,
            "JSON:\n\n```json\n#{JSON.pretty_generate(params_for_template).strip}\n```\n\n"
          )
        end
      end

      # Update model if specified in loaded data
      if data["parameters"] && data["parameters"]["model"]
        loaded_model = data["parameters"]["model"]
        if OpenAI::AVAILABLE_MODELS.key?(loaded_model)
          @params["model"] = loaded_model
          print "Model set to: #{loaded_model}\n"
        else
          print "Warning: Model '#{loaded_model}' not available, keeping current model\n"
        end
      end

      print "Data has been loaded successfully (#{@messages.size} messages)\n"
      true
    rescue StandardError => e
      print "Error loading data: #{e.message}\n"
      false
    end
  end
end
