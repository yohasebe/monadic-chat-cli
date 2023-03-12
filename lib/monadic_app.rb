# frozen_string_literal: true

require_relative "./monadic_chat"
require_relative "./monadic_chat/console"
require_relative "./monadic_chat/formatting"
require_relative "./monadic_chat/interaction"
require_relative "./monadic_chat/menu"
require_relative "./monadic_chat/parameters"
require_relative "./monadic_chat/internals"

Thread.abort_on_exception = false

class MonadicApp
  include MonadicChat
  attr_reader :template

  def initialize(params, template, placeholders, prop_accumulated, prop_newdata, update_proc)
    @threads = Thread::Queue.new
    @responses = Thread::Queue.new
    @placeholders = placeholders
    @prop_accumulated = prop_accumulated
    @prop_newdata = prop_newdata
    @completion = nil
    @update_proc = update_proc
    @params_original = params
    @params = @params_original.dup
    @template_original = File.read(template)
    @method = OpenAI.model_to_method @params["model"]

    case @method
    when "completions"
      @template = @template_original.dup
    when "chat/completions"
      @template = JSON.parse @template_original
    end
  end

  ##################################################
  # methods for running monadic app
  ##################################################

  def parse(input = nil)
    loop do
      case input
      when TrueClass
        input = user_input
        next
      when /\A\s*(?:help|menu|commands?|\?|h)\s*\z/i
        return true unless show_menu
      when /\A\s*(?:bye|exit|quit)\s*\z/i
        break
      when /\A\s*(?:reset)\s*\z/i
        reset
      when /\A\s*(?:data|context)\s*\z/i
        show_data
      when /\A\s*(?:html)\s*\z/i
        set_html
      when /\A\s*(?:save)\s*\z/i
        save_data
      when /\A\s*(?:load)\s*\z/i
        load_data
      when /\A\s*(?:clear|clean)\s*\z/i
        clear_screen
      when /\A\s*(?:params?|parameters?|config|configuration)\s*\z/i
        change_parameter
      else
        if input && confirm_query(input)
          begin
            case @method
            when "completions"
              bind_research_mode(input, num_retry: NUM_RETRY)
            when "chat/completions"
              bind_normal_mode(input, num_retry: NUM_RETRY)
            end
          rescue StandardError => e
            input = ask_retrial(input, e.message)
            next
          end
        end
      end
      if input.to_s == ""
        input = false
        clear_screen
      end
      input = user_input
    end
  rescue MonadicError
    false
  end

  def banner(title, desc, color)
    screen_width = TTY::Screen.width - 2
    width = screen_width < TITLE_WIDTH ? screen_width : TITLE_WIDTH
    title = PASTEL.bold.send(color.to_sym, title.center(width, " "))
    desc = desc.center(width, " ")
    padding = "".center(width, " ")
    banner = TTY::Box.frame "#{padding}\n#{title}\n#{desc}\n#{padding}"
    print "\n", banner.strip, "\n"
  end

  def run
    banner("MONADIC::CHAT / #{self.class.name}", self.class::DESC, self.class::COLOR)
    show_greet

    if @placeholders.empty?
      parse(user_input)
    else
      loadfile = PROMPT_SYSTEM.select("\nLoad saved file? (Make sure the file is saved by the same app)", default: 2, show_help: :never) do |menu|
        menu.choice "Yes", "yes"
        menu.choice "No", "no"
      end
      parse(user_input) if loadfile == "yes" && load_data || fulfill_placeholders
    end
  end
end
