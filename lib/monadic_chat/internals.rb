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
      end
      true
    end
  end

  def objectify
    case @mode
    when :research
      m = /JSON:\n+```json\s*(\{.+\})\s*```\n\n/m.match(@template)
      return @messages unless m # Return messages if no JSON match
      json = m[1].gsub(/(?!\\\\\\)\\\\"/) { '\\\"' }

      res = parse_research_json(json)
      res["messages"] = @messages
      res
    when :normal
      @messages
    end
  end

  # Parse research mode JSON with fallback for nested markdown structures
  def parse_research_json(json)
    # First try direct parsing
    begin
      res = JSON.parse(json)
      # Check if result is nested markdown wrapper ({"response":"```json...```"})
      if res.is_a?(Hash) && res.keys == ["response"] && res["response"].is_a?(String)
        inner_str = res["response"]
        # Try to extract inner JSON from markdown wrapper
        inner_result = extract_json_from_markdown(inner_str)
        return inner_result if inner_result
      end
      return res
    rescue JSON::ParserError
      # Fall through to try extraction methods
    end

    # Try to extract JSON from markdown wrapper in the raw string
    extracted = extract_json_from_markdown(json)
    return extracted if extracted

    # Try with escaped newlines/quotes unescaped
    begin
      unescaped = json.gsub(/\\n/, "\n").gsub(/\\"/, '"')
      extracted = extract_json_from_markdown(unescaped)
      return extracted if extracted
      return JSON.parse(unescaped)
    rescue JSON::ParserError
      # Fall through
    end

    # Last resort: return with error flag
    { "response" => json, "error" => "JSON parsing failed" }
  end

  # Extract JSON object from markdown code block
  def extract_json_from_markdown(str)
    return nil unless str.is_a?(String)

    # Unescape common escape sequences
    unescaped = str.gsub(/\\n/, "\n").gsub(/\\"/, '"').gsub(/\\\\/, "\\")

    # Try to find JSON in markdown code block
    if unescaped =~ /```json\s*(\{[\s\S]*?\})\s*```/m
      candidate = Regexp.last_match(1)
      begin
        return JSON.parse(candidate)
      rescue JSON::ParserError
        # Try again with better brace matching
      end
    end

    # Try balanced brace extraction for JSON objects
    if unescaped =~ /\{.*"mode"\s*:/m
      begin
        # Find the JSON object containing "mode"
        extracted = extract_balanced_json(unescaped)
        return JSON.parse(extracted) if extracted
      rescue JSON::ParserError
        # Fall through
      end
    end

    nil
  end

  # Extract a balanced JSON object from a string
  def extract_balanced_json(str)
    start_idx = str.index("{")
    return nil unless start_idx

    depth = 0
    in_string = false
    escape_next = false

    (start_idx...str.length).each do |i|
      char = str[i]

      if escape_next
        escape_next = false
        next
      end

      if char == "\\"
        escape_next = true
        next
      end

      if char == '"' && !escape_next
        in_string = !in_string
        next
      end

      next if in_string

      if char == "{"
        depth += 1
      elsif char == "}"
        depth -= 1
        return str[start_idx..i] if depth.zero?
      end
    end

    nil
  end

  def prepare_params(input_role, input)
    params = @params.dup

    delimited_input = case input_role
                      when "user"
                        "NEW PROMPT: ###\n#{input}\n###"
                      when "system" # i.e. search engine
                        "SEARCH SNIPPETS: ###\n#{input}\n###"
                      when "tool" # continue after tool execution
                        nil
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
        when "tool"
          # Include tool results in messages
          messages << "- tool: #{content}\n"
        else
          messages << "- #{mes["role"].strip}: #{content}\n"
        end
      end

      delimited_messages = "MESSAGES: ###\n#{messages}\n###"
      template = @template.dup.sub("{{SYSTEM}}", system)
                          .sub("{{PROMPT}}", delimited_input.to_s)
                          .sub("{{MESSAGES}}", delimited_messages.strip)

      @template_tokens = count_tokens(template)

      File.open(TEMP_MD, "w") { |f| f.write template }

      @messages << { "role" => input_role, "content" => input } if input_role != "tool"

      case @method
      when "completions"
        params["prompt"] = template
      when "chat/completions", "responses"
        # For both Chat Completions API and Responses API,
        # set messages with template as system message
        # (Responses API will convert this via convert_to_responses_format)
        params["messages"] = [{ "role" => "system", "content" => template }]
      end

    when :normal
      @messages << { "role" => input_role, "content" => input } if input_role != "tool"
      params["messages"] = @messages
    end

    # Add tools if registered for this app
    tools = tools_for_api
    params["tools"] = tools if tools

    @update_proc.call unless input_role == "system" || input_role == "tool"

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

  # Maximum iterations for tool execution loop to prevent infinite loops
  MAX_TOOL_ITERATIONS = 10

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

    # Get structured output schema for research mode
    # NOTE: Structured output is currently disabled pending further testing
    # To enable, set MONADIC_STRUCTURED_OUTPUT=1 environment variable
    structured_output = nil
    if research_mode && ENV["MONADIC_STRUCTURED_OUTPUT"]
      model = params["model"]
      method = OpenAI.model_to_method(model)
      if method == OpenAI::API_RESPONSES
        structured_output = MonadicChat.research_schema_for_responses_api(@app_name)
      else
        structured_output = MonadicChat.research_schema_for_chat_completions_api(@app_name)
      end
    end

    # Tool execution loop - handles multiple iterations of tool calls
    iteration = 0
    res = nil

    loop do
      iteration += 1
      if iteration > MAX_TOOL_ITERATIONS
        print PROMPT_SYSTEM.prefix, "Maximum tool iterations reached\n"
        break
      end

      escaping = +""
      finished = false

      res = @completion.run(params,
                            research_mode: research_mode && iteration == 1 ? false : research_mode, # Skip JSON parsing during tool loop
                            timeout_sec: SETTINGS["timeout_sec"],
                            num_retrials: num_retrials,
                            structured_output: structured_output) do |chunk|
        if chunk.instance_of?(Hash) && chunk["content"] == "DONE"
          finished = true
        elsif chunk.instance_of?(String) && !finished
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

          print chunk
        end
      end

      # Check for native tool calls (Hash with "tool_calls" key)
      if res.is_a?(Hash) && res["tool_calls"] && !res["tool_calls"].empty?
        tool_calls = res["tool_calls"]
        text_content = res["text"]

        # Add assistant message with tool calls to messages
        assistant_msg = { "role" => "assistant" }
        assistant_msg["content"] = text_content if text_content && !text_content.empty?
        assistant_msg["tool_calls"] = tool_calls
        @messages << assistant_msg

        # Execute tools and add results
        print "\n", PROMPT_SYSTEM.prefix, "Executing #{tool_calls.size} tool(s)...\n"

        tool_results = execute_tools_parallel(tool_calls)
        tool_results.each do |tool_result|
          @messages << tool_result
          # Print tool result summary
          result_preview = tool_result["content"].to_s[0, 100]
          result_preview += "..." if tool_result["content"].to_s.length > 100
          print "  Tool result: #{result_preview}\n"
        end

        # Continue the loop with tool results
        params = prepare_params("tool", nil)
        print PROMPT_ASSISTANT.prefix, "\n"
        next
      end

      # No tool calls - exit the loop
      break
    end

    print "\n"

    # If we exited the loop with tool_calls still in response (max iterations reached),
    # extract the text content for further processing
    if res.is_a?(Hash) && res["tool_calls"]
      res = res["text"] || ""
    end

    # Handle nil response (should not happen normally)
    res ||= ""

    # Handle the final response (after tool loop completes or if no tool calls)
    message = case role
              when "system" # i.e. search engine; the response given above should be by "assistant"
                { role: "assistant", content: @mode == :research ? unit(res) : res }
              when "user", "tool" # the response give above should be either "assistant"
                # Fallback to legacy pattern-based tool detection if native tools didn't fire
                searched = use_tool_legacy(res)
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
                  { role: "assistant", content: @mode == :research ? unit(res) : res }
                end
              end

    update_template(message[:content], message[:role])

    set_html if @html
  end

  ##################################################
  # Legacy pattern-based tool detection (backward compatibility)
  # Used when native tool calls are not available or for apps
  # that don't have tools registered
  ##################################################

  def use_tool_legacy(res)
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
      bing_search(search_key, @web_search_cache)
    else
      false
    end
  end

  # Alias for backward compatibility
  alias use_tool use_tool_legacy
end
