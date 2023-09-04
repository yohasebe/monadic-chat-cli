# frozen_string_literal: true

module MonadicChat
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

        SETTINGS["max_tokens_wiki"] = 1000 unless SETTINGS["max_chars_wiki"].to_i.between?(100, 4000)
        SETTINGS["num_retrials"] = 2 unless SETTINGS["num_retrials"].to_i.between?(1, 10)
        SETTINGS["min_query_size"] = 5 unless SETTINGS["min_query_size"].to_i.between?(1, 20)
        SETTINGS["timeout_sec"] = 120 unless SETTINGS["timeout_sec"].to_i.between?(10, 600)

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
          SETTINGS["access_token"] = access_token
          f.write(JSON.pretty_generate(SETTINGS))
          print "New access token has been saved to #{CONFIG}\n\n" if message
          print "Please #{PASTEL.bold.green("restart")} Monadic Chat\n"
          exit
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
      SETTINGS.merge!(config)
      access_token = config["access_token"]
      completion = check.call(access_token)
    else
      access_token ||= PROMPT_SYSTEM.ask("Input your OpenAI access token:")
      return false if access_token.to_s == ""

      completion = check.call(access_token)
      if completion
        File.open(CONFIG, "w") do |f|
          SETTINGS["access_token"] = access_token
          f.write(JSON.pretty_generate(SETTINGS))
        end
        print "Access token has been saved to #{CONFIG}\n\n" if message
        print "Please #{PASTEL.bold.green("restart")} Monadic Chat\n"
        exit
      end
    end
    completion || authenticate(overwrite: true)
  end
end
