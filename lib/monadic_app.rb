# frozen_string_literal: true

require_relative "./monadic_chat"
require_relative "./monadic_chat/console"
require_relative "./monadic_chat/formatting"
require_relative "./monadic_chat/interaction"
require_relative "./monadic_chat/menu"
require_relative "./monadic_chat/parameters"
require_relative "./monadic_chat/internals"
require_relative "./monadic_chat/tools"
require_relative "./monadic_chat/research_schemas"
require_relative "./monadic_chat/tool_definitions"
require_relative "./monadic_chat/tool_executor"

class MonadicApp
  include MonadicChat
  attr_reader :template, :messages, :turns, :app_name

  ##################################################
  # Tool registration class methods
  ##################################################

  class << self
    attr_accessor :registered_tools, :tools_enabled

    # Enable native tool use for this app
    # @param tool_sets [Array<Symbol>] Tool categories to enable
    #   Available categories:
    #   - :search - Wikipedia and web search tools
    #   - :wikipedia - Only Wikipedia search
    #   - :web - Only web search
    #   - :batch - Batch processing tools
    #   - :file - File operation tools
    #   - :all - All available tools
    #
    # @example Enable search tools
    #   class MyApp < MonadicApp
    #     enable_tools :search
    #   end
    #
    # @example Enable multiple tool sets
    #   class BatchApp < MonadicApp
    #     enable_tools :batch, :file
    #   end
    def enable_tools(*tool_sets)
      @tools_enabled = true
      @registered_tools ||= []

      tool_sets.each do |set|
        case set
        when :search
          @registered_tools.concat(MonadicChat::ToolDefinitions::SEARCH_TOOLS)
        when :wikipedia
          @registered_tools << MonadicChat::ToolDefinitions::WIKIPEDIA_SEARCH
        when :web
          @registered_tools << MonadicChat::ToolDefinitions::WEB_SEARCH
        when :batch
          @registered_tools.concat(MonadicChat::ToolDefinitions::BATCH_TOOLS)
        when :file
          @registered_tools.concat(MonadicChat::ToolDefinitions::FILE_TOOLS)
        when :all
          @registered_tools.concat(MonadicChat::ToolDefinitions::ALL_TOOLS)
        end
      end

      @registered_tools.uniq! { |t| t.dig("function", "name") }
    end

    # Inherit tool registration from parent class
    def inherited(subclass)
      super
      subclass.instance_variable_set(:@registered_tools, @registered_tools&.dup || [])
      subclass.instance_variable_set(:@tools_enabled, @tools_enabled || false)
    end
  end

  # Initialize class-level defaults
  @registered_tools = []
  @tools_enabled = false

  ##################################################
  # Tool registration instance methods
  ##################################################

  # Get tools array for API calls
  # @return [Array<Hash>, nil] Tool definitions or nil if not enabled
  def tools_for_api
    return nil unless self.class.tools_enabled
    return nil if self.class.registered_tools.nil? || self.class.registered_tools.empty?

    # Check if model supports tool calling
    spec = OpenAI.model_spec(@params["model"])
    unless spec&.dig("tool_capability")
      # Model doesn't support tools - fall back to pattern-based
      return nil
    end

    self.class.registered_tools
  end

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

    # Store app name for structured output schema lookup
    @app_name = self.class.name.downcase

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
            bind(input, num_retrials: SETTINGS["num_retrials"])
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
