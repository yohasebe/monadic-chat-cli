# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for preparation and updating
  ##################################################

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
                PROMPT_SYSTEM.readline("#{val}: ")
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
    message = PASTEL.red "Processing contextual data #{SPINNER} "
    print message

    TIMEOUT_SEC.times do |i|
      raise MonadicError, "Error: something went wrong" if i + 1 == TIMEOUT_SEC

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

  ##################################################
  # functions for binding data
  ##################################################

  def bind_normal_mode(input, num_retry: 0)
    print PROMPT_ASSISTANT.prefix, "\n"
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

      if count_lines_below > 1
        print PASTEL.magenta(last_chunk)
      elsif !spinning
        print PASTEL.red SPINNER
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

    text = text.gsub(/(?!\\\\)\\/) { "" }
    print TTY::Markdown.parse(text).gsub("{{NEWLINE}}") { "\n" }.strip
    print "\n"

    update_template(res)
  end

  def bind_research_mode(input, num_retry: 0)
    print PROMPT_ASSISTANT.prefix, "\n"

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
              if count_lines_below > 1
                print PASTEL.magenta(last_chunk)
              elsif !spinning
                print PASTEL.red SPINNER
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
          TTY::Cursor.backword(SPINNER.size)
          TTY::Cursor.clear_char(SPINNER.size)
        end
        @responses << response.sub(/\s+###\s*".*/m, "")
      end

      update_template(res)
      @threads.clear
    rescue StandardError => e
      @threads.clear
      @responses << <<~ERROR
        Error: something went wrong in a thread"
        #{e.message}
        #{e.backtrace}
      ERROR
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

        text = text.gsub(/(?!\\\\)\\/) { "" }
        print TTY::Markdown.parse(text).gsub("{{NEWLINE}}") { "\n" }.strip
        print "\n"
        break
      end
    end
  end
end
