# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for user interaction
  ##################################################

  def user_input(text = "")
    res = PROMPT_USER.readline(text)
    print TTY::Cursor.clear_line_after
    res == "" ? nil : res
  end

  def show_greet
    current_mode = case @mode
                   when :research
                     PASTEL.red("Research")
                   when :normal
                     PASTEL.green("Normal")
                   end
    greet_md = <<~GREET
      - You are currently in **#{current_mode}** mode (#{@params["model"]})
      - Type **help** or **menu** to see available commands
    GREET
    print PROMPT_SYSTEM.prefix
    print "\n#{TTY::Markdown.parse(greet_md, indent: 0).strip}\n"
  end

  def confirm_query(input)
    if input.size < SETTINGS["min_query_size"]
      PROMPT_SYSTEM.yes?("Would you like to proceed with this (very short) prompt?")
    else
      true
    end
  end
end
