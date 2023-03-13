# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for formatting and presenting
  ##################################################
  def format_data
    contextual = []
    accumulator = []

    if @method == "completions"
      objectify.each do |key, val|
        next if %w[prompt response messages].include? key

        contextual << "- **#{key.split("_").map(&:capitalize).join(" ")}**: #{val.to_s.strip}"
      end
    end

    @messages.each do |m|
      accumulator << "#{m["role"].capitalize}: #{m["content"]}".sub("\n\n###\n\n", "")
    end

    h1 = "# Monadic :: Chat / #{self.class.name}"
    contextual.map!(&:strip).unshift "## Contextual Data\n" unless contextual.empty?

    accum_label = @prop_accumulator.split("_").map(&:capitalize).join(" ")
    accumulator.map!(&:strip).unshift "## #{accum_label}\n" unless accumulator.empty?

    "#{h1}\n\n#{contextual.join("\n")}\n\n#{accumulator.join("\n\n")}"
  end

  def show_data
    print PROMPT_SYSTEM.prefix

    wait

    res = format_data
    print "\n#{TTY::Markdown.parse(res, indent: 0)}"
  end

  def set_html
    res = format_data.sub(%r{::(.+?)/(.+?)\b}) do
      " <span class='monadic_gray'>::</span> <span class='monadic_app'>#{Regexp.last_match(1)}</span> <span class='monadic_gray'>/</span> #{Regexp.last_match(2)}"
    end
    res = res.gsub("```") { "~~~" }
             .gsub(/^(system):/i) { "<span class='monadic_system'> #{Regexp.last_match(1)} </span><br />" }
             .gsub(/^(user):/i) { "<span class='monadic_user'> #{Regexp.last_match(1)} </span><br />" }
             .gsub(/^(assistant|gpt):/i) { "<span class='monadic_chat'> #{Regexp.last_match(1)} </span><br />" }
    add_to_html(res, TEMP_HTML)
  end

  def show_html
    wait
    set_html
    print PROMPT_SYSTEM.prefix
    print "HTML is ready\n"
    Launchy.open(TEMP_HTML)
  end

  def add_to_html(text, filepath)
    text = text.gsub(/(?<![\\>\s])(?!\n[\n<])\n/m) { "<br/>\n" }
    text = text.gsub(/~~~(.+?)~~~/m) do
      m = Regexp.last_match
      "~~~#{m[1].gsub("<br/>\n") { "\n" }}~~~"
    end
    text = text.gsub(/`(.+?)`/) do
      m = Regexp.last_match
      "`#{m[1].gsub("<br/>\n") { "\n" }}`"
    end

    `touch #{filepath}` unless File.exist?(filepath)
    File.open(filepath, "w") do |f|
      html = <<~HTML
        <!doctype html>
          <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style type="text/css">
                #{GITHUB_STYLE}
              </style>
              <title>Monadic Chat</title>
            </head>
            <body>
                #{Kramdown::Document.new(text, syntax_highlighter: :rouge, syntax_highlighter_ops: {}).to_html}
            </body>
            <script src="https://code.jquery.com/jquery-3.6.3.min.js"></script>
            <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
            <script>
              $(window).on("load", function() {
                $("html, body").animate({ scrollTop: $(document).height() }, 500);
              });
            </script>
          </html>
      HTML
      f.write html
    end
  end
end
