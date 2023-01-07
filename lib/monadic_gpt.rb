# frozen_string_literal: true

require_relative "monadic_gpt/version"
require_relative "monadic_gpt/open_ai"
require_relative "monadic_gpt/helper"

require "tty-markdown"
require_relative "monadic_gpt/tty_markdown_no_br"
require "tty-prompt"
require "tty-spinner"
require "tty-box"
require "pastel"
require "oj"

Oj.mimic_JSON

module MonadicGpt
  CONFIG = File.join(Dir.home, "monadic_gpt.conf")
  NUM_RETRY = 1
  MIN_LENGTH = 10

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

  spinner_opts = { clear: true, format: :arrow_pulse }
  SPINNER = TTY::Spinner.new(PASTEL.cyan("❯ Thinking :spinner"), spinner_opts)
  BULLET = "\e[33m●\e[0m"

  class App
    attr_reader :template

    def initialize(params, template, placeholders, prop_accumulated, prop_newdata, update_proc)
      @template_original = File.read(template)
      @template = @template_original.dup
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

    def reset
      if @placeholders.empty?
        @template = @template_original.dup
        MonadicGpt.prompt_monadic
        print "❯ Context has been reset.\n"
      else
        fulfill_placeholders
      end
    end

    def textbox(text = "")
      # if @placeholders.empty?
      PROMPT.ask(text)
      # else
      #   PROMPT.multiline(text).join("\n")
      # end
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
      print "\n#{TTY::Markdown.parse(res, indent: 0).strip}\n"
    end

    def prepare_params(input)
      template = @template.dup.sub("{{PROMPT}}", input)
      params = @params.dup
      params[:prompt] = template
      params
    end

    def ask_retrial(input, message = nil)
      MonadicGpt.prompt_monadic
      print "❯ Error: #{message.capitalize}\n" if message
      retrial = PROMPT.select(" Do you want to try again?") do |menu|
        menu.choice "Yes", "yes"
        menu.choice "No", "no"
        menu.choice "Show current contextual data", "show"
      end
      case retrial
      when "yes"
        input
      when "no"
        MonadicGpt.prompt_user
        textbox
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
        overwrite = PROMPT.select(" #{filepath} already exists.\nOverwrite?") do |menu|
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
      parameter = PROMPT.select(" Select the parmeter to be set:",
                                per_page: 7,
                                cycle: true,
                                show_help: :always,
                                filter: true,
                                default: 1) do |menu|
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
      PROMPT.ask(" Set value of max tokens [16 to 8000]", convert: :int) do |q|
        q.in "16-8000"
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
      model = PROMPT.select(" Select a model:",
                            per_page: 10,
                            cycle: false,
                            show_help: :always,
                            filter: true,
                            default: 1) do |menu|
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
        # List of Commands
        - **help**, **menu**, **commands**: show this help
        - **params**, **settings**, **config**: show and change values of parameters
        - **data**, **context**: show current contextual info
        - **reset**: reset context to original state
        - **save**: save current contextual info to file
        - **load**: load contextual info from file
        - **clear**, **clean**: clear screen
        - **bye**, **exit**, **quit**: go back to main menu
      HELP
      MonadicGpt.prompt_monadic
      print "\n#{TTY::Markdown.parse(help_md, indent: 0).strip}\n"
    end

    def bind_and_unwrap(input, num_retry: 0)
      params = prepare_params(input)
      res = @completion.run_expecting_json(params, num_retry: num_retry)
      update_template(res)
      res
    end

    def confirm_query(input)
      if input.size < MIN_LENGTH
        MonadicGpt.prompt_monadic
        PROMPT.yes?(" Would you like to proceed with this (very short) prompt?")
      else
        true
      end
    end

    def parse(input = nil)
      loop do
        case input
        when /\A\s*(?:help|menu|commands?|\?|h)\s*\z/i
          show_help
        when /\A\s*(?:bye|exit|quit)\s*\z/i
          break
        when /\A\s*(?:reset)\s*\z/i
          reset
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
          if input && confirm_query(input)
            begin
              MonadicGpt.prompt_gpt3
              SPINNER.auto_spin
              res = bind_and_unwrap(input, num_retry: NUM_RETRY)
              text = res[@prop_newdata]
              @started = true
              SPINNER.stop("")
              print "❯ #{TTY::Markdown.parse(text).strip}\n"
            rescue StandardError => e
              SPINNER.stop("")
              input = ask_retrial(input, e.message)
              next
            end
          end
        end
        MonadicGpt.prompt_user
        input = textbox
      end
    end

    def fulfill_placeholders
      input = nil
      replacements = []
      mode = :replace

      @placeholders.each do |key, val|
        if key == "mode"
          mode = val
          next
        end

        input = if mode == :replace
                  val
                else
                  textbox(" #{val}:")
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
        true
      end
    end

    def run
      MonadicGpt.banner(self.class.name, self.class::DESC, "cyan", "blue")
      show_help
      if @placeholders.empty?
        parse
      else
        MonadicGpt.prompt_monadic
        loadfile = PROMPT.select(" Load saved file?", default: 2) do |menu|
          menu.choice "Yes", "yes"
          menu.choice "No", "no"
        end
        parse if loadfile == "yes" && load_data || fulfill_placeholders
      end
    end
  end
end
