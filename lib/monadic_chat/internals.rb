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

  def prepare_params(input_role, input)
    params = @params.dup

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
        else
          messages << "- #{mes["role"].strip}: #{content}\n"
        end
      end
      template = @template.dup.sub("{{SYSTEM}}", system)
                          .sub("{{PROMPT}}", input)
                          .sub("{{MESSAGES}}", messages.strip)

      @template_tokens = count_tokens(template)

      File.open(TEMP_MD, "w") { |f| f.write template }

      @messages << { "role" => input_role, "content" => input }

      case @method
      when "completions"
        params["prompt"] = template
      when "chat/completions"
        params["messages"] = [{ "role" => "system", "content" => template }]
      end

    when :normal
      @messages << { "role" => input_role, "content" => input }
      params["messages"] = @messages
    end

    @update_proc.call unless input_role == "system"

    params
  end

  def update_template(res, role)
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
    remove_intermediate_messages if role == "system"
  end

  def remove_intermediate_messages
    @messages = @messages.reject { |ele| ele["role"] == "assistant" && /SEARCH\(.+\)/m =~ ele["content"] }
    @messages = @messages.reject { |ele| ele["role"] == "system" && /^SEARCH SNIPPETS/ =~ ele["content"] }
  end

  ##################################################
  # function to bind data
  ##################################################

  def bind(input, role: "user", num_retry: 0)
    @turns += 1 if role == "user"
    print PROMPT_ASSISTANT.prefix, "\n"
    params = prepare_params(role, input)
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

    webdata = use_tool(res)
    update_template(res, role) unless webdata
    if webdata && role != "system"
      bind(webdata, role: "system", num_retry: num_retry)
    elsif @html
      set_html
    end
  end

  ##################################################
  # function to have GPT use tools
  ##################################################

  def use_tool(res)
    case @mode
    when :normal
      text = res
    when :research
      text = res.is_a?(Hash) ? res["response"] : res
    end

    case text
    when /\bSEARCH_WIKI\((.+?)\)/m
      search_key = Regexp.last_match(1)
      search_keys = search_key.split(",").map do |key|
        key.strip.sub(/^"(.+)"$/, '\1')
      end
      text = "SEARCH SNIPPETS\n#{wikipedia_search(*search_keys)}"
      return text
    when /\bSEARCH_WEB\("?(.+?)"?\)/m
      search_key = Regexp.last_match(1)
      text = "SEARCH SNIPPETS\n#{bing_search(search_key)}"
      return text
    end

    false
  end
end
