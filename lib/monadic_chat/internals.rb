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

    delimited_input = case input_role
                      when "user"
                        "NEW PROMPT: ###\n#{input}\n###"
                      when "system" # i.e. search engine
                        "SEARCH SNIPPETS: ###\n#{input}\n###"
                      end

    case @mode
    when :research
      messages = +""
      system = +""
      @messages.each do |mes|
        role = mes["role"]
        content = mes["content"]
        case role
        when "system"
          system << "#{content}\n" if system == ""
        else
          messages << "- #{mes["role"].strip}: #{content}\n"
        end
      end

      delimited_messages = "MESSAGES: ###\n#{messages}\n###"
      template = @template.dup.sub("{{SYSTEM}}", system)
                          .sub("{{PROMPT}}", delimited_input)
                          .sub("{{MESSAGES}}", delimited_messages.strip)

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
      @messages << { "role" => role, "content" => @metadata["response"] }
      json = @metadata.to_json.strip
      File.open(TEMP_JSON, "w") { |f| f.write json }
      @template.sub!(/JSON:\n+```json.+```\n\n/m, "JSON:\n\n```json\n#{json}\n```\n\n")
    when :normal
      @messages << { "role" => "assistant", "content" => res }
    end
  end

  ##################################################
  # function to package plain text into a unit
  ##################################################

  def unit(input)
    if input.instance_of?(Hash)
      input
    else
      @metadata["response"] = input
      @metadata
    end
  end

  ##################################################
  # function to bind data
  ##################################################

  def bind(input, role: "user", num_retrials: 0)
    case role
    when "user"
      @turns += 1
    when "system" # i.e. search engine
      input = "\n\n#{input}"
    end

    print PROMPT_ASSISTANT.prefix, "\n"
    params = prepare_params(role, input)
    research_mode = @mode == :research

    escaping = +""
    last_chunk = +""

    res = @completion.run(params,
                          research_mode: research_mode,
                          timeout_sec: SETTINGS["timeout_sec"],
                          num_retrials: num_retrials) do |chunk|
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

    message = case role
              when "system" # i.e. search engine; the response given above should be by "assistant"
                { role: "assistant", content: @mode == :research ? unit(res) : res }
              when "user" # the response give above should be either "assistant"
                searched = use_tool(res)
                # but if the response is a search query, it should be by "system" (search engine)
                if searched
                  @messages << { "role" => "assistant",
                                 "content" => @mode == :research ? unit(res)["response"] : res }
                  if searched == "empty"
                    print PROMPT_SYSTEM.prefix, "Search results are empty", "\n"
                    return
                  else
                    bind(searched, role: "system")
                    return
                  end
                # otherwise, it should be by "assistant"
                else
                  { role: "assistant", content: @mode == :researh ? unit(res) : res }
                end
              end

    update_template(message[:content], message[:role])

    set_html if @html
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
    when /\bSEARCH_WIKI\("?(.+?)"?\)/m
      @wiki_search_cache ||= {}
      search_key = Regexp.last_match(1)
      wikipedia_search(search_key, @wiki_search_cache)
    when /\bSEARCH_WEB\("?(.+?)"?\)/m
      @web_search_cache ||= {}
      search_key = Regexp.last_match(1)
      bing_search(search_key, @web_searh_cache)
    else
      false
    end
  end
end
