# frozen_string_literal: true

require "tty-cursor"
require "tty-screen"
require "tty-markdown"
require "tty-prompt"
require "tty-box"
require "pastel"
require "oj"
require "kramdown"
require "rouge"
require "launchy"
require "io/console"

require_relative "./monadic_chat/version"
require_relative "./monadic_chat/tty_markdown_no_br"
require_relative "./monadic_chat/open_ai"

Oj.mimic_JSON

class Cursor
  class << self
    def pos
      res = +""
      $stdin.raw do |stdin|
        $stdout << "\e[6n"
        $stdout.flush
        while (c = stdin.getc) != "R"
          res << c if c
        end
      end
      m = res.match(/(?<row>\d+);(?<column>\d+)/)
      { row: Integer(m[:row]), column: Integer(m[:column]) }
    end
  end
end

module MonadicChat
  CONFIG = File.join(Dir.home, "monadic_chat.conf")
  NUM_RETRY = 1
  MIN_LENGTH = 5
  TIMEOUT_SEC = 120

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

  interrupt = proc do
    MonadicChat.clear_screen
    res = TTY::Prompt.new.yes?("Quit the app?")
    exit if res
  end

  TEMP_HTML = File.join(Dir.home, "monadic_chat.html")
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
    }
    .monadic_chat {
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #ffcaca;
    }
    .monadic_system {
      display:inline-block;
      padding-left: 0.5em;
      padding-right: 0.5em;
      font-weight: bold;
      background-color: #c4ffcb;
    }
    .monadic_gray {
      display:inline-block;
      font-weight: bold;
      color: #999;
    }
    .monadic_app {
      display:inline-block;
      font-weight: bold;
      color: #EB742B;
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
    shellscript = <<~SHELL
      if [[ "$OSTYPE" == "darwin"* ]]; then
        open "#{url}"
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v xdg-open >/dev/null 2>&1; then
          xdg-open "#{url}"
        else
          echo "#{url}"
        fi
      else
        echo "#{url}"
      fi
    SHELL
    `#{shellscript}`
  end

  def self.authenticate(overwrite: false)
    check = lambda do |token|
      print "Checking configuration ▹▹▹▹▹ "
      begin
        raise if OpenAI.models(token).empty?

        print "success\n"
        OpenAI::Completion.new(token)
      rescue StandardError
        print "failure.\n"
        authenticate(overwrite: true)
      end
    end

    access_token = ENV["OPENAI_API_KEY"]
    if overwrite
      access_token = nil
      access_token ||= PROMPT_SYSTEM.ask(" Input your OpenAI access token:")

      check.call(access_token)

      File.open(CONFIG, "w") do |f|
        config = { "access_token" => access_token }
        f.write(JSON.pretty_generate(config))
        print "New access token has been saved to #{CONFIG}\n"
      end
    elsif File.exist?(CONFIG)
      json = File.read(CONFIG)
      config = JSON.parse(json)
      access_token = config["access_token"]
      check.call(access_token)
    else
      access_token ||= PROMPT_SYSTEM.ask(" Input your OpenAI access token:")
      check.call(access_token)
      File.open(CONFIG, "w") do |f|
        config = { "access_token" => access_token }
        f.write(JSON.pretty_generate(config))
        print "Access token has been saved to #{CONFIG}\n"
      end
    end
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

  def self.banner(title, desc, color)
    title = title.center(60, " ")
    desc = desc.center(60, " ")
    padding = "".center(60, " ")
    banner = <<~BANNER
      #{PASTEL.send(:"on_#{color}", padding)}
      #{PASTEL.send(:"on_#{color}").bold(title)}
      #{PASTEL.send(:"on_#{color}", desc)}
      #{PASTEL.send(:"on_#{color}", padding)}
    BANNER
    # print TTY::Box.frame banner.strip
    print "\n", banner.strip, "\n\n"
  end

  PROMPT_USER = TTY::Prompt.new(active_color: :blue, prefix: prompt_user, interrupt: interrupt)
  PROMPT_SYSTEM = TTY::Prompt.new(active_color: :blue, prefix: prompt_system, interrupt: interrupt)

  BULLET = "\e[33m●\e[0m"

  def self.clear_screen
    MonadicChat.clear_region_below
    print "\e[2J\e[f"
  end

  def self.add_to_html(text, filepath)
    text = text.gsub(/(?<![\\>\s])(?!\n[\n<])\n/m) { "<br/>\n" }
    text = text.gsub(/~~~(.+?)~~~/m) do
      m = Regexp.last_match
      "~~~#{m[1].gsub("<br/>\n") { "\n" }}~~~"
    end
    text = text.gsub(/`(.+?)`/) do
      m = Regexp.last_match
      "`#{m[1].gsub("<br/>\n") { "\n" }}`"
    end

    `touch #{filepath}` unless File.exist?(filepath)
    File.open(filepath, "w") do |f|
      html = <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style type="text/css">
              #{GITHUB_STYLE}
            </style>
            <title>Monadic Chat</title>
          </head>
          <body>
              #{Kramdown::Document.new(text, syntax_highlighter: :rouge, syntax_highlighter_ops: {}).to_html}
          </body>
          <script src="https://code.jquery.com/jquery-3.6.3.min.js"></script>
          <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
          <script>
            $(window).on("load", function() {
              $("html, body").animate({ scrollTop: $(document).height() }, 500);
            });
          </script>
        </html>
      HTML
      f.write html
    end
    Launchy.open(filepath)
  end

  def self.count_lines_below
    screen_height = TTY::Screen.height
    vpos = Cursor.pos[:row]
    screen_height - vpos
  end

  def self.confirm_query(input)
    if input.size < MIN_LENGTH
      print TTY::Cursor.save
      res = PROMPT_SYSTEM.yes?(" Would you like to proceed with this (very short) prompt?")
      print TTY::Cursor.restore
      MonadicChat.clear_region_below
      res
    else
      true
    end
  end

  def self.clear_region_below
    print TTY::Cursor.up
    print TTY::Cursor.clear_screen_down
    print TTY::Cursor.up
  end
end
