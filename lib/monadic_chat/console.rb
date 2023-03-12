# frozen_string_literal: true

class MonadicApp
  def count_lines_below
    screen_height = TTY::Screen.height
    vpos = Cursor.pos[:row]
    screen_height - vpos
  end

  def go_up_and_clear
    print TTY::Cursor.up
    print TTY::Cursor.clear_screen_down
    print TTY::Cursor.up
  end

  def clear_screen
    print "\e[2J\e[f"
  end

  def ask_clear
    PROMPT_SYSTEM.readline(PASTEL.red("Press Enter to clear screen"))
    print TTY::Cursor.up
    print TTY::Cursor.clear_screen_down
    clear_screen
  end
end
