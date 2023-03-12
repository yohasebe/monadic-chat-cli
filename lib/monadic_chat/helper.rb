# frozen_string_literal: true

class Cursor
  class << self
    def pos
      res = +""
      $stdin.raw do |stdin|
        $stdout << "\e[6n"
        $stdout.flush
        while (c = stdin.getc) != "R"
          res << c if c
        end
      end
      m = res.match(/(?<row>\d+);(?<column>\d+)/)
      { row: Integer(m[:row]), column: Integer(m[:column]) }
    end
  end
end

module TTY
  class PromptX < Prompt
    attr_reader :prefix

    def initialize(active_color:, prefix:, history: true)
      @interrupt = lambda do
        print TTY::Cursor.clear_screen_down
        print "\e[2J\e[f"
        res = TTY::Prompt.new.yes?("Quit the app?")
        exit if res
      end

      super(active_color: active_color, prefix: prefix, interrupt: @interrupt)
      @history = history
      @prefix = prefix
    end

    def readline(text = "")
      puts @prefix
      begin
        Readline.readline(text, @history)
      rescue Interrupt
        @interrupt.call
      end
    end
  end

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
        # result << content.join.gsub(/(?<!#{symbols})\n(?!#{symbols})/m) { " " }.gsub(/ +/) { " " }
        result << content.join.gsub(/(?<!#{symbols})\n(?!#{symbols})/m) { "" }
        result << NEWLINE unless result.last.to_s.end_with?(NEWLINE)
        result
      end
    end
  end
end

class MonadicError < StandardError
end
