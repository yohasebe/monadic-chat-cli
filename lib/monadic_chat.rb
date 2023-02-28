# frozen_string_literal: true

require_relative "monadic_chat/helper"

Thread.abort_on_exception = false

module MonadicChat
  class App
    attr_reader :template

    def initialize(params, template, placeholders, prop_accumulated, prop_newdata, update_proc)
      @responses = Thread::Queue.new
      @threads = Thread::Queue.new
      @cursor = TTY::Cursor
      @template_original = File.read(template)
      @template = @template_original.dup
      @placeholders = placeholders
      @prop_accumulated = prop_accumulated
      @prop_newdata = prop_newdata
      @completion = nil
      @update_proc = update_proc
      @show_html = false
      @params_original = params
      @params = @params_original.dup
    end

    def wait
      MonadicChat::TIMEOUT_SEC.times do |i|
        raise "Error: something went wrong" if i + 1 == MonadicChat::TIMEOUT_SEC
        break if @threads.empty?

        sleep 1
      end
      self
    end

    def reset
      @show_html = false
      @params = @params_original.dup
      @template = @template_original.dup
      if @placeholders.empty?
        # MonadicChat.prompt_monadic
        print "❯ Context and parameters has been reset.\n"
      else
        fulfill_placeholders
      end
    end

    def textbox(text = "")
      set_cursor
      input = PROMPT.ask(text)
      return input if input == "" || %w[exit clear config].include?(input)

      print @cursor.save
      SPINNER1.auto_spin

      MonadicChat::TIMEOUT_SEC.times do |i|
        raise "Error: something went wrong" if i + 1 == MonadicChat::TIMEOUT_SEC

        print @cursor.restore
        print @cursor.clear_screen_down
        break if @threads.empty?

        sleep 1
      end
      SPINNER1.stop("")
      input
    end

    def update_template(res)
      updated = @update_proc.call(res)
      json = updated.to_json.strip
      @template.sub!(/\n\n```json.+```\n\n/m, "\n\n```json\n#{json}\n```\n\n")
    end

    def objectify
      m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
      JSON.parse(m[1])
    end

    def format_data
      accumulated = +"## #{@prop_accumulated.split("_").map(&:capitalize).join(" ")}\n"
      contextual = +"## Contextual Data\n"

      newdata = ""
      objectify.each do |key, val|
        next if %w[prompt response].include? key

        if key == @prop_accumulated
          # val = val.map do |v|
          #   if v.instance_of?(String)
          #     v.sub(/\s+###\s*$/m, "")
          #   else
          #     v.map { |w| w.sub(/\s+###\s*$/m, "") }[0..1]
          #   end
          # end
          accumulated << val.join("\n\n")
        elsif key == @prop_newdata
          newdata = "- **#{key.capitalize}**: #{val}\n"
        else
          contextual << "- **#{key.capitalize}**: #{val}\n"
        end
      end
      contextual << newdata

      h1 = self.class.name
      "# #{h1}\n\n#{contextual}\n#{accumulated}"
    end

    def show_data
      res = format_data
      # MonadicChat.prompt_monadic
      print "\n#{TTY::Markdown.parse(res, indent: 0).strip}\n"
    end

    def set_html
      # MonadicChat.prompt_monadic
      print " HTML rendering is enabled\n"
      @show_html = true
      show_html
    end

    def show_html
      res = format_data.sub(/::(.+)?\b/) { " <span class='monadic_gray'>::</span> <span class='monadic_app'>#{Regexp.last_match(1)}</span>" }
                       .gsub("```") { "~~~" }
                       .gsub("User:") { "<span class='monadic_user'> User </span><br />" }
                       .gsub("GPT:") { "<span class='monadic_chat'> GPT </span><br />" }
      MonadicChat.add_to_html(res, TEMP_HTML)
    end

    def prepare_params(input)
      template = @template.dup.sub("{{PROMPT}}", input).sub("{{MAX_TOKENS}}", (@params["max_tokens"] / 2).to_s)
      params = @params.dup
      params[:prompt] = template
      params
    end

    def ask_retrial(input, message = nil)
      # MonadicChat.prompt_monadic
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
        # MonadicChat.prompt_user
        textbox
      when "show"
        show_data
        ask_retrial(input)
      end
    end

    def save_data
      # MonadicChat.prompt_monadic
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
      # MonadicChat.prompt_monadic
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
      PROMPT.ask(" Set value of max tokens [1000 to 8000]", convert: :int) do |q|
        q.in "1000-8000"
        q.messages[:range?] = "Value out of expected range [1000 to 2048]"
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
      # MonadicChat.prompt_monadic
      puts "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
    end

    def show_help
      help_md = <<~HELP
        # List of Commands
        - **help**, **menu**, **commands**: show this help
        - **params**, **settings**, **config**: show and change values of parameters
        - **data**, **context**: show current contextual info
        - **html** : view contextual info on the default web browser
        - **reset**: reset context to original state
        - **save**: save current contextual info to file
        - **load**: load contextual info from file
        - **clear**, **clean**: clear screen
        - **bye**, **exit**, **quit**: go back to main menu
      HELP
      # MonadicChat.prompt_monadic
      print "\n#{TTY::Markdown.parse(help_md, indent: 0).strip}\n\n"
    end

    def set_cursor
      vpos = Cursor.pos[:row]
      screen_height = TTY::Screen.height
      gap = (screen_height / 4 * 3) - vpos
      return unless gap.negative?

      print @cursor.down((screen_height - vpos).abs)
      ((screen_height - vpos)).times do
        print @cursor.scroll_down
      end
      print @cursor.up((screen_height - vpos) * 2)
    end

    def bind_and_unwrap(input, num_retry: 0)
      set_cursor
      params = prepare_params(input)
      print @cursor.save
      print "❯ "
      start_vpos = Cursor.pos[:row]
      Thread.new do
        response_all_shown = false
        key_start = /"#{@prop_newdata}":\s*"/
        # key_finish = /\s+###\s+"/m
        key_finish = /(?!\\)"/
        started = false
        escaping = +""
        last_chunk = +""
        finished = false
        @threads << true
        response = +""
        past_five_lines = false
        spinning = false
        res = @completion.run_expecting_json(params, num_retry: num_retry) do |chunk|
          if finished && !response_all_shown
            response_all_shown = true
            print "\n"
            # @responses << response.sub(/\s+###\s+".*/m, "")
            @responses << response.sub(/(?!\\)".*/m, "")
            SPINNER2.stop("")
          end

          unless finished
            if escaping
              chunk = escaping + chunk
              escaping = ""
            end

            if /(?:\\\z)/ =~ chunk
              escaping += chunk
              next
            else
              chunk = chunk.gsub('\\n', "\n")
              response << chunk
            end

            if started && !finished
              if key_finish =~ response
                finished = true
              else
                past_five_lines = (Cursor.pos[:row] - start_vpos) >= 5
                if past_five_lines && !spinning
                  SPINNER2.auto_spin
                else
                  print MonadicChat::PASTEL.magenta(last_chunk)
                end
                last_chunk = chunk
              end
            elsif !started && !finished && key_start =~ response
              started = true
              response = +""
            end
          end
        end
        update_template(res)
        @threads.clear
        show_html if @show_html
      rescue StandardError
        @threads.clear
        @responses << "Error: something went wrong in a thread"
      end

      loop do
        if @responses.empty?
          sleep 1
        else
          print @cursor.restore
          print @cursor.clear_screen_down
          # text = @responses.pop.sub(/\s+###\s+".*/m, "")
          text = @responses.pop.sub(/(?!\\)".*/m, "")
          text = text.gsub(/(?!\\\\)\\/) { "" }
          print "❯ #{TTY::Markdown.parse(text).strip}\n"
          break
        end
      end
      print "\n"
      set_cursor
    end

    def confirm_query(input)
      if input.size < MIN_LENGTH
        # MonadicChat.prompt_monadic
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
        when /\A\s*(?:html)\s*\z/i
          set_html
        when /\A\s*(?:save)\s*\z/i
          save_data
        when /\A\s*(?:load)\s*\z/i
          load_data
        when /\A\s*(?:clear|clean)\s*\z/i
          MonadicChat.clear_screen
        when /\A\s*(?:params?|parameters?|config|configuration)\s*\z/i
          change_parameter
        else
          if input && confirm_query(input)
            begin
              # MonadicChat.prompt_gpt
              bind_and_unwrap(input, num_retry: NUM_RETRY)
            rescue StandardError => e
              SPINNER1.stop("")
              SPINNER2.stop("")
              input = ask_retrial(input, e.message)
              next
            end
          end
        end
        # MonadicChat.prompt_user
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
      MonadicChat.banner(self.class.name, self.class::DESC, "cyan", "blue")
      show_help
      if @placeholders.empty?
        parse
      else
        # MonadicChat.prompt_monadic
        loadfile = PROMPT.select(" Load saved file?", default: 2) do |menu|
          menu.choice "Yes", "yes"
          menu.choice "No", "no"
        end
        parse if loadfile == "yes" && load_data || fulfill_placeholders
      end
    end
  end
end
