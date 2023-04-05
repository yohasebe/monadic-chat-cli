# frozen_string_literal: true

class MonadicApp
  ##################################################
  # method for web search
  ##################################################

  def bing_search(query, num_retrial: 3)
    base_uri = "https://www.bing.com/search?setlang=en"
    css_selector = "#b_results"

    q = URI.encode_www_form(q: query)
    doc = Nokogiri::HTML(URI.parse([base_uri, q].join("&")).read)
    doc.css("script, link").each(&:remove)
    doc.css(css_selector).text.squeeze(" \n")
  rescue StandardError
    num_retrial -= 1
    if num_retrial.positive?
      sleep 1
      bing_search(keywords, num_retrial: num_retrial)
    else
      "empty"
    end
  end

  def wikipedia_search(keywords, cache = {}, num_retrial: 10)
    base_url = "https://en.wikipedia.org/w/api.php"
    search_params = {
      action: "query",
      list: "search",
      format: "json",
      srsearch: keywords,
      utf8: 1,
      formatversion: 2
    }

    search_uri = URI(base_url)
    search_uri.query = URI.encode_www_form(search_params)
    search_response = Net::HTTP.get(search_uri)
    search_data = JSON.parse(search_response)

    raise if search_data["query"]["search"].empty?

    title = search_data["query"]["search"][0]["title"]

    return cache[title] if cache.keys.include?(title)

    content_params = {
      action: "query",
      prop: "extracts",
      format: "json",
      titles: title,
      explaintext: 1,
      utf8: 1,
      formatversion: 2
    }

    content_uri = URI(base_url)
    content_uri.query = URI.encode_www_form(content_params)
    content_response = Net::HTTP.get(content_uri)
    content_data = JSON.parse(content_response)

    result_data = content_data["query"]["pages"][0]["extract"]
    tokenized = BLINGFIRE.text_to_ids(result_data)
    if tokenized.size > SETTINGS["max_tokens_wiki"].to_i
      ratio = SETTINGS["max_tokens_wiki"].to_f / tokenized.size
      result_data = result_data[0..(result_data.size * ratio).to_i]
    end

    text = <<~TEXT
      ```MediaWiki
      #{result_data}
      ```
    TEXT
    cache[title] = text

    text
  rescue StandardError
    num_retrial -= 1
    if num_retrial.positive?
      sleep 1
      wikipedia_search(keywords, num_retrial: num_retrial)
    else
      "empty"
    end
  end
end
