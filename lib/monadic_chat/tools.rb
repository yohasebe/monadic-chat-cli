# frozen_string_literal: true

class MonadicApp
  ##################################################
  # method for web search
  ##################################################

  def bing_search(query, retrial: 5)
    uri = "https://www.bing.com/search"
    css_selector = "#b_results"

    q = URI.encode_www_form(q: query)
    doc = Nokogiri::HTML(URI.parse([uri, q].join("?")).read)
    doc.css("script, link").each(&:remove)
    doc.css(css_selector).text.squeeze(" \n")
  rescue StandardError
    return "SEARCH ENGINE NOT AVAILABLE" if retrial.zero?

    sleep 1
    retrial -= 1
    bing_search(query, retrial: retrial)
  end

  def wikipedia_search(keywords, base_url = nil)
    base_url ||= "https://en.wikipedia.org/w/api.php"
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

    content_data["query"]["pages"][0]["extract"][0..1000]
  rescue StandardError
    "SEARCH RESULTS EMPTY"
  end
end
