# frozen_string_literal: true

require_relative "monadic_gpt/version"
require_relative "monadic_gpt/open_ai"

require "tty-markdown"
require "tty-prompt"
require "tty-spinner"
require "tty-box"
require "pastel"
require "json"

module MonadicGpt
  CONFIG = File.join(Dir.home, "monadic_gpt.conf")

  template_dir = File.join(__dir__, "..", "templates")
  templates = Dir["#{template_dir}/*.md"]
  template_map = {}
  templates.each do |template|
    template_map[File.basename(template, ".md")] = template
  end

  TEMPLATES = template_map

  PASTEL = Pastel.new

  PROMPT = TTY::Prompt.new

  spinner_opts = { clear: true, format: :pulse_2 }
  SPINNER = TTY::Spinner.new(PASTEL.cyan("[:spinner] Thinking ..."), spinner_opts)

  BULLET = "\e[33m●\e[0m"

  class App
    def initialize(params, template, prop_accumulated, prop_newdata, update_proc)
      @template = File.read(template)
      @prop_accumulated = prop_accumulated
      @prop_newdata = prop_newdata
      @completion = nil
      @started = false
      @update_proc = update_proc
      @params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.0,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0
      }.merge(params)
    end

    def update_template(res)
      updated = @update_proc.call(res)
      json = updated.to_json.strip
      @template.sub!(/```json.+?```/m, "```json\n#{json}\n```")
    end

    def show_data
      m = /```json\n(.+?)\n```/m.match(@template)
      data = JSON.parse(m[1])

      accumulated = +"##{@prop_accumulated.capitalize}\n"
      others = +"#Contextual Data\n"
      data.each do |key, val|
        if key == @prop_accumulated
          accumulated << val.to_s
        else
          others << "- **#{key.capitalize}**: #{val}\n"
        end
      end

      prompt_monadic
      res = "#{others}\n#{accumulated}"
      print "#{TTY::Markdown.parse(res, indent: 0).strip}\n\n"
    end

    def prepare_params(input)
      template = @template.clone.sub("{{PROMPT}}", input)
      params = @params.clone
      params[:prompt] = template
      params
    end

    def ask_retrial(input)
      retrial = PROMPT.select("Something went wrong. Do you want to try again?") do |menu|
        menu.choice "yes"
        menu.choice "no"
        menu.choice "show current contextual data"
      end
      case retrial
      when "yes"
        input
      when "show current contextual data"
        show_data
        ask_retrial(input)
      end
    end

    def prompt_monadic
      box_width = 10
      name = "Monadic".center(box_width, " ")
      color = "magenta"
      print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
    end

    def prompt_user
      box_width = 10
      color = "green"
      name = "User".center(box_width, " ")
      print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
    end

    def prompt_gpt3
      box_width = 10
      color = "red"
      name = "GPT-3".center(box_width, " ")
      print "\n#{PASTEL.send(:"on_#{color}", name)}\n"
    end

    def banner
      title = self.class.name.center(40, " ")
      help = "Type \"help\" for menu".center(40, " ")
      padding = "".center(40, " ")
      banner = <<~BANNER
        #{PASTEL.on_cyan(padding)}
        #{PASTEL.on_cyan.bold(title)}
        #{PASTEL.on_cyan(help)}
        #{PASTEL.on_cyan(padding)}
      BANNER
      TTY::Box.frame banner.strip
    end

    def spinner(command)
      case command
      when :start
        SPINNER.auto_spin
      when :stop
        SPINNER.stop("")
      end
    end

    def save_data
      prompt_monadic
      input = PROMPT.ask("Enter the path and file name of the saved data:\n")
      return if input.to_s == ""

      filepath = File.expand_path(input)
      dirname = File.dirname(filepath)
      unless Dir.exist? dirname
        print "Directory does not exist\n"
        save_data
      end
      FileUtils.touch(filepath)
      unless File.exist? filepath
        print "File cannot be created\n"
        save_data
      end
      File.open(filepath, "w") do |f|
        m = /```json\n(.+)\n```/m.match(template)
        f.write JSON.pretty_generate(JSON.parse(m[1]))
        print "Data has been saved successfully\n"
      end
    end

    def load_data
      input = PROMPT.ask("Enter the path and file name of the saved data:\n")
      return if input.to_s == ""

      filepath = File.expand_path(input)
      unless File.exist? filepath
        print "File does not exit\n"
        load_data
      end
      json = File.read(filepath)
      new_template = template.sub(/```json.+?```/m, "```json\n#{json.strip}\n```")
      print "Data has been loaded successfully\n"
      @template = new_template
    end

    def reset_parameter
      prompt_monadic
      parameter = PROMPT.select("Select the parmeter to be set:", per_page: 7, cycle: true, default: 7) do |menu|
        menu.choice "#{BULLET} model: #{@params["model"]}", "model"
        menu.choice "#{BULLET} max_tokens: #{@params["max_tokens"]}", "max_tokens"
        menu.choice "#{BULLET} temperature: #{@params["temperature"]}", "temperature"
        menu.choice "#{BULLET} top_p: #{@params["top_p"]}", "top_p"
        menu.choice "#{BULLET} frequency_penalty: #{@params["frequency_penalty"]}", "frequency_penalty"
        menu.choice "#{BULLET} presence_penalty: #{@params["presence_penalty"]}", "presence_penalty"
        menu.choice "#{BULLET} cancel", "cancel"
      end
      return if parameter == "cancel"

      current_value = @params[parameter]
      value = PROMPT.ask("Set value of #{parameter} (current = #{current_value}):")
      if value
        case parameter
        when "model"
          @params[parameter] = value
        when "max_tokens"
          @params[parameter] = value.to_i
        when "temperature",
          "top_p",
          "frequency_penalty",
          "presence_penalty"
          @params[parameter] = value.to_f
        end
        puts "Parameter #{parameter} has been set to #{PASTEL.green(value)}"
      else
        puts "Parameter #{parameter} has not been changed"
      end
    end

    def show_params
      params_md = "# Current Parameter Values\n\n"
      @params.each do |key, val|
        next if /\A(?:prompt|stream|logprobs|echo|stop)\z/ =~ key

        params_md += "- #{key}: #{val}\n"
      end
      prompt_monadic
      puts "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
    end

    def authenticate(overwrite: false)
      if overwrite
        prompt_monadic
        access_token = nil
        access_token ||= PROMPT.mask("Input Input your API key:") until access_token

        File.open(CONFIG, "w") do |f|
          config = { "access_token" => access_token }
          f.write(JSON.pretty_generate(config))
          print "New access token has been saved to #{CONFIG}\n"
        end
      elsif File.exist?(CONFIG)
        json = File.read(CONFIG)
        config = JSON.parse(json)
        access_token = config["access_token"]
      else
        access_token ||= PROMPT.mask("Input Input your API key:") until access_token
        File.open(CONFIG, "w") do |f|
          config = { "access_token" => access_token }
          f.write(JSON.pretty_generate(config))
          print "New access token has been saved to config\n"
        end
      end

      print "Checking configuration ... "
      begin
        @completion = OpenAI::Completion.new(access_token)
        raise if OpenAI.models(access_token).empty?

        print "success.\n"
        print "Please enter your input.\n"
      rescue StandardError
        print "failure.\n"
        authenticate(overwrite: true)
      end
    end

    def show_help
      prompt_monadic
      help_md = <<~HELP
        # List of Commands\n\n
        - **help** or **commands**: show this help
        - **params**, **settings**, or **config**: show and change values of parameters
        - **data** or **context**: show current contextual info
        - **save** : save current contextual info to file
        - **load** : load contextual info from file
        - **bye**, **exit**, or **quit**: quit the app
      HELP
      print "#{TTY::Markdown.parse(help_md, indent: 0).strip}\n"
    end

    def parse(input)
      loop do
        case input
        when /\A(?:help|commands?|\?|h)\z/i
          show_help
        when /\A(?:bye|exit|quit)\z/i
          break
        when /\A(?:data|context)\z/i
          show_data
        when /\A(?:save)\z/i
          save_data
        when /\A(?:load)\z/i
          load_data
        when /\A(?:params?|parameters?|config|configuration)\z/i
          reset_parameter
        else
          unless input.to_s.strip.empty?
            begin
              spinner(:start)
              params = prepare_params(input)
              res = @completion.run_expecting_json(params, enable_retry: false)
              spinner(:stop)
              prompt_gpt3
              print "#{TTY::Markdown.parse(res[@prop_newdata]).strip}\n"
              update_template(res)
              @started = true
            rescue StandardError
              # pp res
              # pp e
              # pp e.backtrace
              spinner(:stop)
              input = ask_retrial(input)
              retry
            end
          end
        end
        prompt_user
        input = PROMPT.ask
      end
    end

    def run
      puts banner
      authenticate
      prompt_user
      input = PROMPT.ask
      parse input
    end
  end
end
