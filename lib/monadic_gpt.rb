# frozen_string_literal: true

require_relative "monadic_gpt/version"
require_relative "monadic_gpt/open_ai"
require_relative "monadic_gpt/helper"

require "tty-markdown"
require "tty-prompt"
require "tty-spinner"
require "tty-box"
require "pastel"
require "json"

module MonadicGpt
  CONFIG = File.join(Dir.home, "monadic_gpt.conf")
  NUM_RETRY = 1

  template_dir = File.join(__dir__, "..", "templates")
  templates = Dir["#{template_dir}/*.md"]
  template_map = {}
  templates.each do |template|
    template_map[File.basename(template, ".md")] = template
  end

  TEMPLATES = template_map
  PASTEL = Pastel.new

  interrupt = proc do
    MonadicGpt.clear_screen
    res = TTY::Prompt.new.yes?("Quit the app?")
    exit if res
  end
  PROMPT = TTY::Prompt.new(active_color: :blue, prefix: "❯", interrupt: interrupt)

  spinner_opts = { clear: true, format: :pulse_2 }
  SPINNER = TTY::Spinner.new(PASTEL.cyan("[:spinner] Thinking ..."), spinner_opts)
  BULLET = "\e[33m●\e[0m"

  class App
    def initialize(params, template, placeholders, prop_accumulated, prop_newdata, update_proc)
      @template = File.read(template)
      @placeholders = placeholders
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
      @template.sub!(/\n\n```json.+```\n\n/m, "\n\n```json\n#{json}\n```\n\n")
    end

    def show_data
      m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
      data = JSON.parse(m[1])

      accumulated = +"##{@prop_accumulated.capitalize}\n"
      others = +"#Contextual Data\n"
      data.each do |key, val|
        if key == @prop_accumulated
          accumulated << val.map { |v| "- #{v}" }.join("\n")
        else
          others << "- **#{key.capitalize}**: #{val}\n"
        end
      end

      MonadicGpt.prompt_monadic
      res = "#{others}\n#{accumulated}"
      print "#{TTY::Markdown.parse(res, indent: 0).strip}\n\n"
    end

    def prepare_params(input)
      template = @template.dup.sub("{{PROMPT}}", input)
      params = @params.dup
      params[:prompt] = template
      params
    end

    def ask_retrial(input)
      retrial = PROMPT.select("Something went wrong. Do you want to try again?") do |menu|
        menu.choice "Yes", "yes"
        menu.choice "No", "no"
        menu.choice "Show current contextual data", "show"
      end
      case retrial
      when "yes"
        input
      when "no"
        MonadicGpt.prompt_user
        PROMPT.ask
      when "show"
        show_data
        ask_retrial(input)
      end
    end

    def save_data
      MonadicGpt.prompt_monadic
      input = PROMPT.ask(" Enter the path and file name of the saved data:\n")
      return if input.to_s == ""

      filepath = File.expand_path(input)
      dirname = File.dirname(filepath)

      unless Dir.exist? dirname
        print "Directory does not exist\n"
        save_data
      end

      if File.exist? filepath
        overwrite = PROMPT.select("#{filepath} already exists.\nOverwrite?") do |menu|
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
      File.open(filepath, "w") do |f|
        m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
        f.write JSON.pretty_generate(JSON.parse(m[1]))
        print "Data has been saved successfully\n"
      end
    end

    def load_data
      input = PROMPT.ask(" Enter the path and file name of the saved data:\n")
      return false if input.to_s == ""

      filepath = File.expand_path(input)
      unless File.exist? filepath
        print "File does not exit\n"
        load_data
      end

      begin
        json = File.read(filepath)
        data = JSON.parse(json)
        raise if data["mode"] != self.class.name.downcase.split("::")[-1]
      rescue StandardError
        print "The data structure is not valid for this app\n"
        return false
      end

      new_template = @template.sub(/\n\n```json\s*\{.+\}\s*```\n\n/m, "\n\n```json\n#{JSON.pretty_generate(data).strip}\n```\n\n")
      print "Data has been loaded successfully\n"
      @template = new_template
      true
    end

    def change_parameter
      MonadicGpt.prompt_monadic
      parameter = PROMPT.select("Select the parmeter to be set:", per_page: 7, cycle: true, default: 1) do |menu|
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
      puts "Parameter #{parameter} has been set to #{PASTEL.green(value)}" if value
    end

    def change_max_tokens
      PROMPT.ask(" Set value of max tokens [16 to 2048]", convert: :int) do |q|
        q.in "16-2048"
        q.messages[:range?] = "Value out of expected range [16 to 2048]"
      end
    end

    def change_temperature
      PROMPT.ask(" Set value of temperature [0.0 to 1.0]", convert: :float) do |q|
        q.in "0.0-1.0"
        q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
      end
    end

    def change_top_p
      PROMPT.ask(" Set value of top_p [0.0 to 1.0]", convert: :float) do |q|
        q.in "0.0-1.0"
        q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
      end
    end

    def change_frequency_penalty
      PROMPT.ask(" Set value of frequency penalty [-2.0 to 2.0]", convert: :float) do |q|
        q.in "-2.0-2.0"
        q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
      end
    end

    def change_presence_penalty
      PROMPT.ask(" Set value of presence penalty [-2.0 to 2.0]", convert: :float) do |q|
        q.in "-2.0-2.0"
        q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
      end
    end

    def change_model
      model = PROMPT.select("Select a model:", per_page: 10, cycle: false, default: 1) do |menu|
        menu.choice "#{BULLET} Cancel", "cancel"
        @completion.models.sort_by { |m| -m["created"] }.each do |m|
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
      MonadicGpt.prompt_monadic
      puts "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
    end

    def show_help
      help_md = <<~HELP
        # List of Commands\n\n
        - **help**, **menu**, or **commands**: show this help
        - **params**, **settings**, or **config**: show and change values of parameters
        - **data** or **context**: show current contextual info
        - **clear** or **clean**: clear screen
        - **save**: save current contextual info to file
        - **load**: load contextual info from file
        - **bye**, **exit**, or **quit**: quit the app
      HELP
      print "#{TTY::Markdown.parse(help_md, indent: 0).strip}\n"
    end

    def bind_and_unwrap(input, num_retry: 0)
      params = prepare_params(input)
      res = @completion.run_expecting_json(params, num_retry: num_retry)
      update_template(res)
      res
    end

    def parse(input = nil)
      loop do
        case input
        when /\A\s*(?:help|menu|commands?|\?|h)\s*\z/i
          show_help
        when /\A\s*(?:bye|exit|quit)\s*\z/i
          break
        when /\A\s*(?:data|context)\s*\z/i
          show_data
        when /\A\s*(?:save)\s*\z/i
          save_data
        when /\A\s*(?:load)\s*\z/i
          load_data
        when /\A\s*(?:clear|clean)\s*\z/i
          MonadicGpt.clear_screen
        when /\A\s*(?:params?|parameters?|config|configuration)\s*\z/i
          change_parameter
        else
          unless input.to_s.strip.empty?
            begin
              MonadicGpt.prompt_gpt3
              SPINNER.auto_spin
              res = bind_and_unwrap(input, num_retry: NUM_RETRY)
              @started = true
              SPINNER.stop("")
              print "#{TTY::Markdown.parse(res[@prop_newdata]).strip}\n"
            rescue StandardError => e
              pp res
              pp e
              pp e.backtrace
              SPINNER.stop("")
              input = ask_retrial(input)
              next
            end
          end
        end
        MonadicGpt.prompt_user
        input = PROMPT.ask
      end
    end

    def fulfill_placeholders
      input = nil
      replacements = []
      mode = :replace

      @placeholders.each do |key, val|
        case key
        when "mode"
          mode = val
          next
        when "{{PROMPT}}"
          input = val
          next
        end

        input = if mode == :replace
                  val
                else
                  PROMPT.ask(" #{val}:")
                end

        unless input
          replacements.clear
          break
        end
        replacements << [key, input]
      end
      if replacements.empty?
        false
      else
        replacements.each do |key, value|
          @template.gsub!(key, value)
        end
        input
      end
    end

    def run
      MonadicGpt.banner(self.class.name, self.class::DESC, "cyan", "blue")
      show_help
      if @placeholders.empty?
        parse
      else
        MonadicGpt.prompt_monadic
        loadfile = PROMPT.select("Load saved file?", default: 2) do |menu|
          menu.choice "Yes", "yes"
          menu.choice "No", "no"
        end
        if loadfile == "yes"
          parse if load_data
        else
          input = fulfill_placeholders
          parse input if input
        end
      end
    end
  end
end
