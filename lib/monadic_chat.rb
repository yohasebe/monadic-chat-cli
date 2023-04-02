# frozen_string_literal: true

require "blingfire"
require "tty-cursor"
require "tty-screen"
require "tty-markdown"
require "tty-spinner"
require "tty-prompt"
require "tty-box"
require "pastel"
require "oj"
require "kramdown"
require "rouge"
require "launchy"
require "io/console"
require "readline"
require "nokogiri"
require "open-uri"
require "wikipedia"

require_relative "./monadic_chat/version"
require_relative "./monadic_chat/open_ai"
require_relative "./monadic_chat/helper"

Oj.mimic_JSON

module MonadicChat
  SETTINGS = {}
  MAX_CHARS_WIKI = 1000
  gpt2model_path = File.absolute_path(File.join(__dir__, "..", "assets", "gpt2.bin"))
  BLINGFIRE = BlingFire.load_model(gpt2model_path)
  CONFIG = File.join(Dir.home, "monadic_chat.conf")
  NUM_RETRY = 2
  MIN_LENGTH = 5
  TIMEOUT_SEC = 120
  TITLE_WIDTH = 72

  APPS_DIR = File.absolute_path(File.join(__dir__, "..", "apps"))
  APPS_DIR_LIST = Dir.entries(APPS_DIR)
                     .reject { |entry| /\A\./ =~ entry || /\A_/ =~ entry.split("/").last }
                     .map { |entry| File.join(APPS_DIR, entry) }
  templates = {}
  APPS_DIR_LIST.each do |app|
    basename = File.basename(app, ".*")
    normal_mode_template = File.absolute_path(File.join(app, "#{basename}.json"))
    templates["normal/#{basename}"] = normal_mode_template if File.exist? normal_mode_template
    research_mode_template = File.absolute_path(File.join(app, "#{basename}.md"))
    templates["research/#{basename}"] = research_mode_template if File.exist? research_mode_template
  end
  APPS = APPS_DIR_LIST.map { |dir| File.basename(dir, ".*") }

  TEMPLATES = templates

  PASTEL = Pastel.new

  TEMP_HTML = File.join(Dir.home, "monadic_chat.html")
  TEMP_JSON = File.join(Dir.home, "monadic_chat.json")
  TEMP_MD = File.join(Dir.home, "monadic_chat.md")

  style = +File.read(File.join(__dir__, "..", "assets", "github.css")).gsub(".markdown-") { "" }
  style << File.read(File.join(__dir__, "..", "assets", "pigments-default.css"))
  style << <<~CSS
    body {
      margin: 50px;
      font-family: "Helvetica Neue", Arial, "Hiragino Kaku Gothic ProN", "Hiragino Sans", Meiryo, sans-serif;
      color: #333
    }
    .monadic_user{
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #c8e5ff;
      margin-bottom: 0.5em;
    }
    .monadic_chat {
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #ffcaca;
      margin-bottom: 0.5em;
    }
    .monadic_system {
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #c4ffcb;
      margin-bottom: 0.5em;
    }
    .monadic_gray {
      display:inline-block;
      font-weight: bold;
      color: #999;
      margin-bottom: 0.5em;
    }
    .monadic_app {
      display:inline-block;
      font-weight: bold;
      color: #EB742B;
      margin-bottom: 0.5em;
    }
  CSS
  GITHUB_STYLE = style

  def self.require_apps
    MonadicChat::APPS_DIR_LIST.each do |app_dir|
      basename = app_dir.split("/").last
      require "#{app_dir}/#{basename}"
    end
  end

  def self.open_readme
    url = "https://github.com/yohasebe/monadic-chat/"
    Launchy.open(url)
  end

  def self.mdprint(str)
    print TTY::Markdown.parse(str, indent: 0)
  end

  def self.authenticate(overwrite: false, message: true)
    check = lambda do |token|
      if message
        print TTY::Cursor.restore
        print TTY::Cursor.clear_screen_down
        print "\n"
        SPINNER.auto_spin
      end

      if !token || token.strip == ""
        if message
          SPINNER.stop
          print TTY::Cursor.restore
          print "\n"
          mdprint "- Authentication: #{PASTEL.bold.red("Failure")}\n" if message
        end
        return false
      end

      begin
        models = OpenAI.models(token)
        raise if models.empty?

        if message
          SPINNER.stop
          print TTY::Cursor.restore, "\n"
          mdprint "#{PASTEL.on_green(" System ")} Config file: `#{CONFIG}`\n"
          print "\n"
          mdprint "- Authentication: #{PASTEL.bold.green("Success")}\n"
        end

        if SETTINGS["normal_model"] && !models.map { |m| m["id"] }.index(SETTINGS["normal_model"])
          if message
            SPINNER.stop
            mdprint "- Normal mode model specified in config file not available\n"
            mdprint "- Fallback to the default model (`#{OpenAI.default_model(research_mode: false)}`)\n"
          end
          SETTINGS["normal_model"] = false
        end
        SETTINGS["normal_model"] ||= OpenAI.default_model(research_mode: false)
        mdprint "- Normal mode model: `#{SETTINGS["normal_model"]}`\n" if message

        if SETTINGS["research_model"] && !models.map { |m| m["id"] }.index(SETTINGS["research_model"])
          if message
            SPINNER.stop
            mdprint "- Research mode model specified in config file not available\n"
            mdprint "- Fallback to the default model (`#{OpenAI.default_model(research_mode: true)}`)\n"
          end
          SETTINGS["research_model"] = false
        end
        SETTINGS["research_model"] ||= OpenAI.default_model(research_mode: true)
        mdprint "- Research mode model: `#{SETTINGS["research_model"]}`\n" if message

        OpenAI::Completion.new(token)
      rescue StandardError
        if message
          SPINNER.stop
          print TTY::Cursor.restore
          print "\n"
          mdprint "- Authentication: #{PASTEL.bold.red("Failure")}\n" if message
        end
        false
      end
    end

    completion = nil

    if overwrite
      access_token = PROMPT_SYSTEM.ask("Input your OpenAI access token:")
      return false if access_token.to_s == ""

      completion = check.call(access_token)

      if completion
        File.open(CONFIG, "w") do |f|
          config = {
            "access_token" => access_token,
            "normal_model" => SETTINGS["normal_model"],
            "research_model" => SETTINGS["research_model"]
          }
          f.write(JSON.pretty_generate(config))
          print "New access token has been saved to #{CONFIG}\n" if message
        end
      end
    elsif File.exist?(CONFIG)
      json = File.read(CONFIG)
      begin
        config = JSON.parse(json)
      rescue JSON::ParserError
        puts "Error: config file does not contain a valid JSON object."
        exit
      end
      SETTINGS["normal_model"] = config["normal_model"] if config["normal_model"]
      SETTINGS["research_model"] = config["research_model"] if config["research_model"]
      access_token = config["access_token"]
      completion = check.call(access_token)
    else
      access_token ||= PROMPT_SYSTEM.ask("Input your OpenAI access token:")
      return false if access_token.to_s == ""

      completion = check.call(access_token)
      if completion
        File.open(CONFIG, "w") do |f|
          config = {
            "access_token" => access_token,
            "normal_model" => SETTINGS["normal_model"],
            "research_model" => SETTINGS["research_model"]
          }
          f.write(JSON.pretty_generate(config))
        end
        print "Access token has been saved to #{CONFIG}\n" if message
      end
    end
    completion || authenticate(overwrite: true)
  end

  def self.prompt_system
    box_width = 8
    name = "System".center(box_width, " ")
    color = "green"
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.prompt_user
    box_width = 6
    color = "blue"
    name = "User".center(box_width, " ")
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.prompt_assistant
    box_width = 5
    color = "red"
    name = "GPT".center(box_width, " ")
    "\n#{PASTEL.send(:"on_#{color}", name)}"
  end

  def self.tokenize(text)
    BLINGFIRE.text_to_ids(text)
  end

  PROMPT_USER = TTY::PromptX.new(active_color: :blue, prefix: prompt_user)
  PROMPT_SYSTEM = TTY::PromptX.new(active_color: :blue, prefix: "#{prompt_system} ")
  PROMPT_ASSISTANT = TTY::PromptX.new(active_color: :red, prefix: "#{prompt_assistant} ")

  SPINNER = TTY::Spinner.new(format: :arrow_pulse, clear: true)

  BULLET = "\e[33m●\e[0m"
end
