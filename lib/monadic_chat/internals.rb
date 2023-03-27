# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for preparation and updating
  ##################################################

  def count_tokens(text)
    MonadicChat.tokenize(text).size
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
        @messages[0]["content"].gsub!(key, value)
        messages[0]["content"]
      end
      true
    end
  end

  def objectify
    case @mode
    when :research
      m = /JSON:\n+```json\s*(\{.+\})\s*```\n\n/m.match(@template)
      json = m[1].gsub(/(?!\\\\\\)\\\\"/) { '\\\"' }
      res = JSON.parse(json)
      res["messages"] = @messages
      res
    when :normal
      @messages
    end
  end

  def prepare_params(input)
    params = @params.dup

    @update_proc.call

    case @mode
    when :research
      messages = +""
      system = +""
      @messages.each do |mes|
        role = mes["role"]
        content = mes["content"]
        case role
        when "system"
          system << "#{content}\n"
        when "assistant", "gpt"
          messages << "- #{mes["role"].strip}: #{content}\n"
        else
          messages << "- #{mes["role"].strip}: #{mes["content"]}\n"
        end
      end
      template = @template.dup.sub("{{SYSTEM}}", system)
                          .sub("{{PROMPT}}", input)
                          .sub("{{MESSAGES}}", messages.strip)

      File.open(TEMP_MD, "w") { |f| f.write template }

      @messages << { "role" => "user", "content" => input }

      case @method
      when "completions"
        params["prompt"] = template
      when "chat/completions"
        params["messages"] = [{ "role" => "system", "content" => template }]
      end

    when :normal
      @messages << { "role" => "user", "content" => input }
      params["messages"] = @messages
    end

    params
  end

  def update_template(res)
    case @mode
    when :research
      @metadata = res
      @messages << { "role" => "assistant", "content" => @metadata["response"] }
      json = @metadata.to_json.strip
      File.open(TEMP_JSON, "w") { |f| f.write json }
      @template.sub!(/JSON:\n+```json.+```\n\n/m, "JSON:\n\n```json\n#{json}\n```\n\n")
    when :normal
      @messages << { "role" => "assistant", "content" => res }
    end
  end

  ##################################################
  # function to bind data
  ##################################################

  def bind(input, num_retry: 0)
    print PROMPT_ASSISTANT.prefix, "\n"
    params = prepare_params(input)
    research_mode = @mode == :research

    escaping = +""
    last_chunk = +""

    res = @completion.run(params, research_mode: research_mode, num_retry: num_retry) do |chunk|
      if escaping
        chunk = escaping + chunk
        escaping = ""
      end

      if /(?:\\\z)/ =~ chunk
        escaping += chunk
        next
      else
        chunk = chunk.gsub('\\n') { "\n" }
      end

      print last_chunk
      last_chunk = chunk
    end

    print last_chunk
    print "\n"

    update_template(res)
    set_html if @html
  end
end
