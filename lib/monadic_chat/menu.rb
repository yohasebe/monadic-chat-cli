# frozen_string_literal: true

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
        case @mode
        when :research
          m = /JSON:\n+```json\s*(\{.+\})\s*```\n\n/m.match(@template)
          data = JSON.parse(m[1])
          data["messages"] = @messages
          f.write JSON.pretty_generate(data)
        when :normal
          f.write JSON.pretty_generate({ "messages" => @messages })
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
      case @mode
      when :research
        self.class.name.downcase.split("::")[-1]

        raise unless data["mode"] == self.class.name.downcase.split("::")[-1]

        @messages = data.delete "messages"
        @template = @template.sub(/JSON:\n+```json\s*\{.+\}\s*```\n\n/m, "JSON:\n\n```json\n#{JSON.pretty_generate(data).strip}\n```\n\n")
      when :normal
        raise unless data["messages"] && data["messages"][0]["role"]

        @messages = data["messages"]
      end
      print "Data has been loaded successfully\n"
      true
    rescue StandardError
      print "The data structure is not valid for this app\n"
      false
    end
  end
end
