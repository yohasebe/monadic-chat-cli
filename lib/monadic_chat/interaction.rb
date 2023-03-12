# frozen_string_literal: true

class MonadicApp
  ##################################################
  # methods for user interaction
  ##################################################

  def user_input(text = "")
    if count_lines_below < 1
      ask_clear
      user_input
    else
      res = PROMPT_USER.readline(text)
      print TTY::Cursor.clear_line_after
      res == "" ? nil : res
    end
  end

  def show_greet
    current_mode = case @method
                   when "completions"
                     PASTEL.red("Research")
                   when "chat/completions"
                     PASTEL.green("Normal")
                   end
    greet_md = <<~GREET
      - You are currently in **#{current_mode}** mode
      - Type **help** or **menu** to see available commands
    GREET
    print PROMPT_SYSTEM.prefix
    print "\n#{TTY::Markdown.parse(greet_md, indent: 0).strip}\n"
  end

  def confirm_query(input)
    if input.size < MIN_LENGTH
      print TTY::Cursor.save
      res = PROMPT_SYSTEM.yes?("Would you like to proceed with this (very short) prompt?")
      print TTY::Cursor.restore
      print TTY::Cursor.up unless res
      go_up_and_clear
      res
    else
      true
    end
  end
end
