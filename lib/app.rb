# frozen_string_literal: true

require_relative "monadic_chat"

Thread.abort_on_exception = true

module MonadicChat
  class App
    attr_reader :template

    def initialize(params, template, placeholders, prop_accumulated, prop_newdata, update_proc)
      @threads = Thread::Queue.new
      @responses = Thread::Queue.new
      @placeholders = placeholders
      @prop_accumulated = prop_accumulated
      @prop_newdata = prop_newdata
      @completion = nil
      @update_proc = update_proc
      @show_html = false
      @params_original = params
      @params = @params_original.dup
      @template_original = File.read(template)
      @method = OpenAI.model_to_method @params["model"]

      case @method
      when "completions"
        @template = @template_original.dup
      when "chat/completions"
        @template = JSON.parse @template_original
      end

      PROMPT_USER.on(:keypress) do |event|
        case event.key.name
        when :ctrl_l
          PROMPT_USER.trigger(:keyenter)
          raise unless show_help
        end
      end
    end

    ########################################
    # methods for preparation and updating
    ########################################

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
                  print "\n"
                  PROMPT_SYSTEM.ask(" #{val}:")
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
          case @method
          when "completions"
            @template.gsub!(key, value)
          when "chat/completions"
            @template["messages"][0]["content"].gsub!(key, value)
          end
        end
        true
      end
    end

    def wait
      return self if @threads.empty?

      print TTY::Cursor.save
      message = PASTEL.red " Processing contextual data ... "
      print message
      MonadicChat::TIMEOUT_SEC.times do |i|
        raise "Error: something went wrong" if i + 1 == MonadicChat::TIMEOUT_SEC

        break if @threads.empty?

        sleep 1
      end
      print TTY::Cursor.restore
      print TTY::Cursor.clear_char(message.size)

      self
    end

    def objectify
      case @method
      when "completions"
        m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
        json = m[1].gsub(/(?!\\\\\\)\\\\"/) { '\\\"' }
        JSON.parse(json)
      when "chat/completions"
        @template
      end
    end

    def prepare_params(input)
      params = @params.dup
      case @method
      when "completions"
        template = @template.dup.sub("{{PROMPT}}", input).sub("{{MAX_TOKENS}}", (@params["max_tokens"] / 2).to_s)
        params["prompt"] = template
      when "chat/completions"
        @template["messages"] << { "role" => "user", "content" => input }
        params["messages"] = @template["messages"]
      end
      params
    end

    def update_template(res)
      case @method
      when "completions"
        updated = @update_proc.call(res)
        json = updated.to_json.strip
        @template.sub!(/\n\n```json.+```\n\n/m, "\n\n```json\n#{json}\n```\n\n")
      when "chat/completions"
        @template["messages"] << { "role" => "assistant", "content" => res }
        @template["messages"] = @update_proc.call(@template["messages"])
      end
    end

    ########################################
    # methods for formatting and presenting
    ########################################
    def format_data
      contextual = []
      accumulated = []

      objectify.each do |key, val|
        next if %w[prompt response].include? key

        if (@method == "completions" && key == @prop_accumulated) ||
           (@method == "chat/completions" && key == "messages")
          val = val.map do |v|
            case @method
            when "completions"
              if v.instance_of?(String)
                v.sub(/\s+###\s*$/m, "")
              else
                v.map { |role, text| "#{role.strip.capitalize}: #{text.sub(/\s+###\s*$/m, "")}" }
              end
            when "chat/completions"
              "#{v["role"].capitalize}: #{v["content"]}"
            end
          end
          accumulated << val.join("\n\n")
        else
          contextual << "- **#{key.to_s.capitalize}**: #{val.to_s.strip}"
        end
      end

      h1 = "# #{self.class.name}\n\n"
      contextual.map!(&:strip).unshift "## Contextual Data\n" unless contextual.empty?
      accum_label = @prop_accumulated.split("_").map(&:capitalize).join(" ")
      accumulated.map!(&:strip).unshift "## #{accum_label}\n" unless accumulated.empty?
      "#{h1}#{contextual.join("\n")}\n\n#{accumulated.join("\n")}"
    end

    def show_data
      print MonadicChat.prompt_system

      wait

      res = format_data
      print "\n#{TTY::Markdown.parse(res, indent: 0).strip}\n"
      MonadicChat.clear_region_below
    end

    def set_html
      print MonadicChat.prompt_system

      wait

      print " HTML rendering is enabled"
      @show_html = true
      show_html
      MonadicChat.clear_region_below
    end

    def show_html
      res = format_data.sub(/::(.+)?\b/) { " <span class='monadic_gray'>::</span> <span class='monadic_app'>#{Regexp.last_match(1)}</span>" }
                       .gsub("```") { "~~~" }
                       .gsub(/^(system):/i) { "<span class='monadic_system'> #{Regexp.last_match(1)} </span><br />" }
                       .gsub(/^(user):/i) { "<span class='monadic_user'> #{Regexp.last_match(1)} </span><br />" }
                       .gsub(/^(assistant|gpt):/i) { "<span class='monadic_chat'> #{Regexp.last_match(1)} </span><br />" }
      MonadicChat.add_to_html(res, TEMP_HTML)
    end

    ########################################
    # methods for user interaction
    ########################################

    def textbox(text = nil)
      MonadicChat.ask_clear
      print "\n"
      res = if text
              PROMPT_USER.ask(text)
            else
              PROMPT_USER.ask
            end
      MonadicChat.clear_region_below

      res
    end

    def show_greet
      current_mode = case @method
                     when "completions"
                       MonadicChat::PASTEL.red("Research")
                     when "chat/completions"
                       MonadicChat::PASTEL.green("Normal")
                     end
      greet_md = <<~GREET
        - You are currently in **#{current_mode}** mode
        - Type **help** or **CTRL-L** to see available commands
      GREET
      print MonadicChat.prompt_system
      print "\n#{TTY::Markdown.parse(greet_md, indent: 0).strip}"
    end

    def show_help
      print TTY::Cursor.save
      parameter = PROMPT_SYSTEM.select(" Select function:",
                                       per_page: 10,
                                       cycle: true,
                                       filter: true,
                                       default: 1,
                                       show_help: :never) do |menu|
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("cancel/return/escape")}   cancel this menu", "cancel"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("params/settings/config")} show and change values of parameters", "params"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("data/context")}           show currrent contextual info", "data"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("html")}                   view contextual info on the web browser", "html"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("reset")}                  reset context to original state", "reset"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("save")}                   save current contextual info to file", "save"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("load")}                   load current contextual info from file", "load"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("clear/clean")}            clear screen", "clear"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("readme/documentation")}   open readme/documentation", "readme"
        menu.choice "#{MonadicChat::BULLET} #{MonadicChat::PASTEL.bold("exit/bye/quit")}          go back to main menu", "exit"
      end

      TTY::Cursor.clear_line
      print TTY::Cursor.restore
      print TTY::Cursor.clear_screen_down

      case parameter
      when "cancel"
        return true
      when "params"
        change_parameter
      when "data"
        show_data
      when "html"
        set_html
      when "reset"
        reset
      when "save"
        save_data
      when "load"
        load_data
      when "clear"
        MonadicChat.clear_screen
        print TTY::Cursor.clear_screen_down
      when "readme"
        MonadicChat.open_readme
      when "exit"
        return false
      end
      true
    end

    def reset
      @show_html = false
      @params = @params_original.dup

      case @method
      when "completions"
        @template = @template_original.dup
      when "chat/completions"
        @template = JSON.parse @template_original
      end

      if @placeholders.empty?
        print MonadicChat.prompt_system
        print " Context and parameters have been reset.\n"
      else
        fulfill_placeholders
      end
    end

    def ask_retrial(input, message = nil)
      print MonadicChat.prompt_system
      print " Error: #{message.capitalize}\n" if message
      retrial = PROMPT_USER.select(" Do you want to try again?",
                                   show_help: :never) do |menu|
        menu.choice "Yes", "yes"
        menu.choice "No", "no"
        menu.choice "Show current contextual data", "show"
      end
      case retrial
      when "yes"
        input
      when "no"
        textbox
      when "show"
        show_data
        ask_retrial(input)
      end
    end

    def save_data
      input = PROMPT_SYSTEM.ask(" Enter the path to the save file (press Enter to cancel): ")
      return if input.to_s.strip == ""

      filepath = File.expand_path(input)
      dirname = File.dirname(filepath)

      unless Dir.exist? dirname
        print "Directory does not exist\n"
        save_data
      end

      if File.exist? filepath
        overwrite = PROMPT_SYSTEM.select(" #{filepath} already exists.\nOverwrite?",
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
      File.open(filepath, "w") do |f|
        case @method
        when "completions"
          m = /\n\n```json\s*(\{.+\})\s*```\n\n/m.match(@template)
          f.write JSON.pretty_generate(JSON.parse(m[1]))
        when "chat/completions"
          f.write JSON.pretty_generate(@template)
        end

        print "Data has been saved successfully\n"
      end
    end

    def load_data
      input = PROMPT_SYSTEM.ask(" Enter the path to the save file (press Enter to cancel): ")
      return if input.to_s.strip == ""

      filepath = File.expand_path(input)
      unless File.exist? filepath
        print "File does not exit\n"
        load_data
      end

      begin
        json = File.read(filepath)
        data = JSON.parse(json)
        case @method
        when "completions"
          raise unless data["mode"] == self.class.name.downcase.split("::")[-1]

          new_template = @template.sub(/\n\n```json\s*\{.+\}\s*```\n\n/m, "\n\n```json\n#{JSON.pretty_generate(data).strip}\n```\n\n")
          @template = new_template
        when "chat/completions"
          raise unless data["messages"] && data["messages"][0]["role"]

          @template["messages"] = data["messages"]
        end
      rescue StandardError
        print "The data structure is not valid for this app"
      end

      print "Data has been loaded successfully"
    end

    ########################################
    # methods for parameter setting
    ########################################

    def change_parameter
      parameter = PROMPT_SYSTEM.select(" Select the parmeter to be set:",
                                       per_page: 7,
                                       cycle: true,
                                       show_help: :never,
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
        case @method
        when "completions"
          @template = @template_original.dup
        when "chat/completions"
          @template = JSON.parse @template_original
        end
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
      print "Parameter #{parameter} has been set to #{PASTEL.green(value)}\n" if value
    end

    def change_max_tokens
      PROMPT_SYSTEM.ask(" Set value of max tokens [1000 to 8000]", convert: :int) do |q|
        q.in "1000-8000"
        q.messages[:range?] = "Value out of expected range [1000 to 2048]"
      end
    end

    def change_temperature
      PROMPT_SYSTEM.ask(" Set value of temperature [0.0 to 1.0]", convert: :float) do |q|
        q.in "0.0-1.0"
        q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
      end
    end

    def change_top_p
      PROMPT_SYSTEM.ask(" Set value of top_p [0.0 to 1.0]", convert: :float) do |q|
        q.in "0.0-1.0"
        q.messages[:range?] = "Value out of expected range [0.0 to 1.0]"
      end
    end

    def change_frequency_penalty
      PROMPT_SYSTEM.ask(" Set value of frequency penalty [-2.0 to 2.0]", convert: :float) do |q|
        q.in "-2.0-2.0"
        q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
      end
    end

    def change_presence_penalty
      PROMPT_SYSTEM.ask(" Set value of presence penalty [-2.0 to 2.0]", convert: :float) do |q|
        q.in "-2.0-2.0"
        q.messages[:range?] = "Value out of expected range [-2.0 to 2.0]"
      end
    end

    def change_model
      model = PROMPT_SYSTEM.select(" Select a model:",
                                   per_page: 10,
                                   cycle: false,
                                   show_help: :never,
                                   filter: true,
                                   default: 1) do |menu|
        menu.choice "#{BULLET} Cancel", "cancel"
        @completion.models.filter { |m| OpenAI.model_to_method(m["id"]) == @method }.sort_by { |m| -m["created"] }.each do |m|
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
      print MonadicChat.prompt_system, "\n"
      print "#{TTY::Markdown.parse(params_md, indent: 0).strip}\n\n"
    end

    ########################################
    # functions for binding data
    ########################################

    def bind_normal_mode(input, num_retry: 0)
      print MonadicChat.prompt_assistant, " "
      print TTY::Cursor.save

      wait

      params = prepare_params(input)
      print TTY::Cursor.save

      escaping = +""
      last_chunk = +""
      response = +""
      spinning = false
      res = @completion.run(params, num_retry: num_retry) do |chunk|
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

        if MonadicChat.count_lines_below > 3
          print MonadicChat::PASTEL.magenta(last_chunk)
        elsif !spinning
          print PASTEL.red " ... "
          spinning = true
        end

        last_chunk = chunk
      end

      print TTY::Cursor.restore
      print TTY::Cursor.clear_screen_down

      text = response.gsub(/(?<![\\>\s])(?!\n[\n<])\n/m) { "{{NEWLINE}}\n" }
      text = text.gsub(/```(.+?)```/m) do
        m = Regexp.last_match
        "```#{m[1].gsub("{{NEWLINE}}\n") { "\n" }}```"
      end
      text = text.gsub(/`(.+?)`/) do
        m = Regexp.last_match
        "`#{m[1].gsub("{{NEWLINE}}\n") { "\n" }}`"
      end

      # text = text.gsub(/(?!\\\\)\\/) { "" }
      print TTY::Markdown.parse(text).gsub("{{NEWLINE}}") { "\n" }.strip

      update_template(res)
      show_html if @show_html
    end

    def bind_research_mode(input, num_retry: 0)
      print MonadicChat.prompt_assistant, " "

      wait

      params = prepare_params(input)
      print TTY::Cursor.save

      @threads << true
      Thread.new do
        response_all_shown = false
        key_start = /"#{@prop_newdata}":\s*"/
        key_finish = /\s+###\s*"/m
        started = false
        escaping = +""
        last_chunk = +""
        finished = false
        response = +""
        spinning = false
        res = @completion.run(params, num_retry: num_retry) do |chunk|
          if finished && !response_all_shown
            response_all_shown = true
            @responses << response.sub(/\s+###\s*".*/m, "")
            if spinning
              TTY::Cursor.backword(" ▹▹▹▹▹ ".size)
              TTY::Cursor.clear_char(" ▹▹▹▹▹ ".size)
            end
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
                if MonadicChat.count_lines_below > 3
                  print MonadicChat::PASTEL.magenta(last_chunk)
                elsif !spinning
                  print PASTEL.red " ... "
                  spinning = true
                end
                last_chunk = chunk
              end
            elsif !started && !finished && key_start =~ response
              started = true
              response = +""
            end
          end
        end

        unless response_all_shown
          if spinning
            TTY::Cursor.backword(" ... ".size)
            TTY::Cursor.clear_char(" ... ".size)
          end
          @responses << response.sub(/\s+###\s*".*/m, "")
        end

        update_template(res)
        @threads.clear
        show_html if @show_html
      rescue StandardError => e
        @threads.clear
        @responses << "Error: something went wrong in a thread"
        pp e
      end

      loop do
        if @responses.empty?
          sleep 1
        else
          print TTY::Cursor.restore
          print TTY::Cursor.clear_screen_down
          text = @responses.pop

          text = text.gsub(/(?<![\\>\s])(?!\n[\n<])\n/m) { "{{NEWLINE}}\n" }
          text = text.gsub(/```(.+?)```/m) do
            m = Regexp.last_match
            "```#{m[1].gsub("{{NEWLINE}}\n") { "\n" }}```"
          end
          text = text.gsub(/`(.+?)`/) do
            m = Regexp.last_match
            "`#{m[1].gsub("{{NEWLINE}}\n") { "\n" }}`"
          end

          # text = text.gsub(/(?!\\\\)\\/) { "" }
          print TTY::Markdown.parse(text).gsub("{{NEWLINE}}") { "\n" }.strip
          break
        end
      end
    end

    ########################################
    # methods for running app
    ########################################

    def parse(input = nil)
      loop do
        case input
        when TrueClass
          input = textbox
          next
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
          if input && MonadicChat.confirm_query(input)
            begin
              case @method
              when "completions"
                bind_research_mode(input, num_retry: NUM_RETRY)
              when "chat/completions"
                bind_normal_mode(input, num_retry: NUM_RETRY)
              end
            rescue StandardError => e
              input = ask_retrial(input, e.message)
              next
            end
          end
        end
        input = textbox
        if input.to_s == ""
          input = false
          MonadicChat.clear_region_below
        end
      end
    rescue StandardError
      false
    end

    def run
      MonadicChat.banner(self.class.name, self.class::DESC, "cyan", "blue")
      show_greet

      if @placeholders.empty?
        parse(textbox)
      else
        print "\n"
        print MonadicChat.prompt_system
        loadfile = PROMPT_SYSTEM.select(" Load saved file?",
                                        default: 2,
                                        show_help: :never) do |menu|
          menu.choice "Yes", "yes"
          menu.choice "No", "no"
        end
        parse(textbox) if loadfile == "yes" && load_data || fulfill_placeholders
      end
    end
  end
end
