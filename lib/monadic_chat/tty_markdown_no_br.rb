# frozen_string_literal: true

# monkeypatching tty-markdown not to output <br />
module TTY
  module Markdown
    # Converts a Kramdown::Document tree to a terminal friendly output
    class Converter < ::Kramdown::Converter::Base
      def convert_p(ell, opts)
        indent = SPACE * @current_indent
        result = []

        result << indent unless %i[blockquote li].include?(opts[:parent].type)

        opts[:indent] = @current_indent
        opts[:indent] = 0 if opts[:parent].type == :blockquote

        content = inner(ell, opts)

        symbols = %q{[-!$%^&*()_+|~=`{}\[\]:";'<>?,.\/]}
        result << content.join.gsub(/(?<!#{symbols})\n(?!#{symbols})/m) { " " }.gsub(/ +/) { " " }
        result << NEWLINE unless result.last.to_s.end_with?(NEWLINE)
        result
      end
    end
  end
end
