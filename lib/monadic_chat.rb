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

require_relative "./monadic_chat/version"
require_relative "./monadic_chat/open_ai"
require_relative "./monadic_chat/authenticate"
require_relative "./monadic_chat/commands"
require_relative "./monadic_chat/helper"

Oj.mimic_JSON

module MonadicChat
  SETTINGS = {
    "normal_model" => "gpt-3.5-turbo-0613",
    "research_model" => "gpt-3.5-turbo-0613",
    "max_tokens_wiki" => 1000,
    "num_retrials" => 2,
    "min_query_size" => 5,
    "timeout_sec" => 120
  }
  gpt2model_path = File.absolute_path(File.join(__dir__, "..", "assets", "gpt2.bin"))

  BLINGFIRE = BlingFire.load_model(gpt2model_path)
  CONFIG = File.join(Dir.home, "monadic_chat.conf")
  TITLE_WIDTH = 72
  APPS_DIR = File.absolute_path(File.join(__dir__, "..", "apps"))
  USER_APPS_DIR = File.absolute_path(File.join(__dir__, "..", "user_apps"))

  apps_dir_list = Dir.entries(APPS_DIR)
                     .reject { |entry| /\A\./ =~ entry || /\A_/ =~ entry.split("/").last }
                     .map { |entry| File.join(APPS_DIR, entry) }

  user_apps_dir_list = Dir.entries(USER_APPS_DIR)
                          .reject { |entry| /\A\./ =~ entry || /\A_/ =~ entry.split("/").last }
                          .reject { |entry| /\Aboilerplates/ =~ entry }
                          .map { |entry| File.join(USER_APPS_DIR, entry) }

  APPS_DIR_LIST = apps_dir_list + user_apps_dir_list

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
    .monadic_search_engine {
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #ffe9c4;
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
  PROMPT_USER = TTY::PromptX.new(active_color: :blue, prefix: prompt_user)
  PROMPT_SYSTEM = TTY::PromptX.new(active_color: :blue, prefix: "#{prompt_system} ")
  PROMPT_ASSISTANT = TTY::PromptX.new(active_color: :red, prefix: "#{prompt_assistant} ")
  SPINNER = TTY::Spinner.new(format: :arrow_pulse, clear: true)
  BULLET = "\e[33m●\e[0m"
  HOME = File.expand_path(File.join(__dir__, ".."))

  def self.require_apps
    MonadicChat::APPS_DIR_LIST.each do |app_dir|
      basename = app_dir.split("/").last
      require "#{app_dir}/#{basename}"
    end
  end
end
