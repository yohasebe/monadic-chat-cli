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

require_relative "./monadic_chat/version"
require_relative "./monadic_chat/open_ai"
require_relative "./monadic_chat/helper"

Oj.mimic_JSON

module MonadicChat
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

  def self.authenticate(overwrite: false, message: true)
    check = lambda do |token, normal_mode_model, research_mode_model|
      print "Checking configuration\n" if message
      SPINNER.auto_spin
      begin
        models = OpenAI.models(token)
        raise if models.empty?

        SPINNER.stop

        print "Success\n" if message

        if normal_mode_model && !models.map { |m| m["id"] }.index(normal_mode_model)
          SPINNER.stop
          print "Normal mode model set in config file not available.\n" if message
          normal_mode_model = false
        end
        normal_mode_model ||= OpenAI.model_name(research_mode: false)
        print "Normal mode model: #{normal_mode_model}\n" if message

        if research_mode_model && !models.map { |m| m["id"] }.index(research_mode_model)
          SPINNER.stop
          print "Normal mode model set in config file not available.\n" if message
          print "Fallback to the default model (#{OpenAI.model_name(research_mode: true)}).\n" if message
        end
        research_mode_model ||= OpenAI.model_name(research_mode: true)
        print "Research mode model: #{research_mode_model}\n" if message

        OpenAI::Completion.new(token, normal_mode_model, research_mode_model)
      rescue StandardError
        SPINNER.stop
        print "Authentication: failure.\n" if message
        false
      end
    end

    completion = nil

    if overwrite
      access_token = PROMPT_SYSTEM.ask(" Input your OpenAI access token:")
      return false if access_token.to_s == ""

      completion = check.call(access_token, nil, nil)

      if completion
        File.open(CONFIG, "w") do |f|
          config = { "access_token" => access_token }
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
      access_token = config["access_token"]
      normal_mode_model = config["normal_mode_model"]
      research_mode_model = config["research_mode_model"]
      completion = check.call(access_token, normal_mode_model, research_mode_model)
    else
      access_token ||= PROMPT_SYSTEM.ask(" Input your OpenAI access token:")
      completion = check.call(access_token, nil, nil)
      if completion
        File.open(CONFIG, "w") do |f|
          config = { "access_token" => access_token }
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
