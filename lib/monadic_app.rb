# frozen_string_literal: true

require_relative "./monadic_chat"
require_relative "./monadic_chat/console"
require_relative "./monadic_chat/formatting"
require_relative "./monadic_chat/interaction"
require_relative "./monadic_chat/menu"
require_relative "./monadic_chat/parameters"
require_relative "./monadic_chat/internals"
require_relative "./monadic_chat/tools"

class MonadicApp
  include MonadicChat
  attr_reader :template, :messages, :turns

  def initialize(mode:, params:, template_json:, template_md:, placeholders:, prop_accumulator:, prop_newdata:, update_proc:)
    @mode = mode.to_sym
    @placeholders = placeholders
    @prop_accumulator = prop_accumulator
    @prop_newdata = prop_newdata
    @completion = nil
    @update_proc = update_proc
    @params_initial = params
    @params = @params_initial.dup
    @html = false

    @method = OpenAI.model_to_method(@params["model"])

    @metadata = {}
    json = File.read(template_json)
               .gsub("{{DATETIME}}", Time.now.strftime("%Y-%m-%d %H:%M:%S"))
               .gsub("{{DATE}}", Time.now.strftime("%Y-%m-%d"))
    @messages_initial = JSON.parse(json)["messages"]
    @messages = @messages_initial.dup
    @turns = 0
    @template_initial = File.read(template_md)
    @template = @template_initial.dup

    @template_tokens = 0
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
        @html = true
        show_html
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
            bind(input, num_retry: NUM_RETRY)
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
    clear_screen
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
