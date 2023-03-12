# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for formatting and presenting
  ##################################################
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
        contextual << "- **#{key.split("_").map(&:capitalize).join(" ")}**: #{val.to_s.strip}"
      end
    end

    h1 = "# #{self.class.name}\n\n"
    contextual.map!(&:strip).unshift "## Contextual Data\n" unless contextual.empty?
    accum_label = @prop_accumulated.split("_").map(&:capitalize).join(" ")
    accumulated.map!(&:strip).unshift "## #{accum_label}\n" unless accumulated.empty?
    "#{h1}#{contextual.join("\n")}\n\n#{accumulated.join("\n")}"
  end

  def show_data
    print PROMPT_SYSTEM.prefix

    wait

    res = format_data
    print "\n#{TTY::Markdown.parse(res, indent: 0)}"
  end

  def set_html
    print PROMPT_SYSTEM.prefix

    wait

    print "HTML rendering is enabled\n"
    @show_html = true
    show_html
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
    Launchy.open(filepath)
  end

  def show_html
    res = format_data.sub(/::(.+)?\b/) { " <span class='monadic_gray'>::</span> <span class='monadic_app'>#{Regexp.last_match(1)}</span>" }
                     .gsub("```") { "~~~" }
                     .gsub(/^(system):/i) { "<span class='monadic_system'> #{Regexp.last_match(1)} </span><br />" }
                     .gsub(/^(user):/i) { "<span class='monadic_user'> #{Regexp.last_match(1)} </span><br />" }
                     .gsub(/^(assistant|gpt):/i) { "<span class='monadic_chat'> #{Regexp.last_match(1)} </span><br />" }
    add_to_html(res, TEMP_HTML)
  end
end
