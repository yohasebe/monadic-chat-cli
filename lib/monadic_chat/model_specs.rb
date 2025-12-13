# frozen_string_literal: true

# Model specifications for Monadic Chat CLI
# Loads model definitions from models.json (synced from Monadic Chat)

require "json"

module OpenAI
  # API types
  API_CHAT_COMPLETIONS = "chat/completions"
  API_RESPONSES = "responses"

  # Load model specifications from JSON file
  MODELS_JSON_PATH = File.join(__dir__, "models.json")
  MODEL_SPECS = if File.exist?(MODELS_JSON_PATH)
                  JSON.parse(File.read(MODELS_JSON_PATH)).freeze
                else
                  {}.freeze
                end

  # Models that require Responses API only (not available in Chat Completions)
  RESPONSES_API_ONLY_MODELS = MODEL_SPECS.select { |_, spec|
    spec["api_type"] == API_RESPONSES && spec["is_agent_model"]
  }.keys.freeze

  # Expensive models that require user confirmation
  EXPENSIVE_MODEL_PATTERNS = [
    /\bgpt-5.*-pro\b/i,
    /\bo3-pro\b/i,
    /\bo1-pro\b/i,
    /\bgpt-5-codex-max\b/i,
    /\bgpt-5\.1-codex-max\b/i
  ].freeze

  # Helper methods for model specifications

  # Get the model specification
  def self.model_spec(model)
    MODEL_SPECS[model]
  end

  # Check if a model is available
  def self.model_available?(model)
    MODEL_SPECS.key?(model)
  end

  # Get the API type for a model
  def self.api_type(model)
    spec = MODEL_SPECS[model]
    spec ? (spec["api_type"] || API_CHAT_COMPLETIONS) : nil
  end

  # Check if a model uses Responses API
  def self.responses_api?(model)
    api_type(model) == API_RESPONSES
  end

  # Check if a model uses Chat Completions API
  def self.chat_completions_api?(model)
    api_type(model) == API_CHAT_COMPLETIONS
  end

  # Check if a model supports temperature parameter
  def self.supports_temperature?(model)
    spec = MODEL_SPECS[model]
    return true unless spec

    # Models with reasoning_effort typically don't support temperature
    # unless they explicitly have a temperature range defined
    if spec["reasoning_effort"] && !spec["temperature"]
      false
    else
      true
    end
  end

  # Check if a model is a reasoning model (has reasoning_effort)
  def self.reasoning_model?(model)
    spec = MODEL_SPECS[model]
    spec && spec["reasoning_effort"]
  end

  # Get the default reasoning effort for a model
  # Returns nil for non-reasoning models
  # Format in models.json: [["available_values"], "default_value"]
  def self.default_reasoning_effort(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["reasoning_effort"]

    effort = spec["reasoning_effort"]
    effort.is_a?(Array) && effort.size >= 2 ? effort[1] : "low"
  end

  # Get available reasoning effort values for a model
  def self.available_reasoning_efforts(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["reasoning_effort"]

    effort = spec["reasoning_effort"]
    effort.is_a?(Array) && effort[0].is_a?(Array) ? effort[0] : nil
  end

  # Check if a model requires confirmation (expensive)
  def self.requires_confirmation?(model)
    spec = MODEL_SPECS[model]
    (spec && spec["requires_confirmation"]) || expensive_model?(model)
  end

  # Check if a model is expensive
  def self.expensive_model?(model)
    EXPENSIVE_MODEL_PATTERNS.any? { |pattern| pattern.match?(model) }
  end

  # Get warning message for expensive models
  def self.expensive_model_warning(model)
    <<~WARNING
      ============================================================
      WARNING: High-cost model selected!

      Model: #{model}

      This model has significantly higher costs compared to
      standard models. A single conversation could cost $10-100+.

      Please ensure you understand the pricing before proceeding.
      ============================================================
    WARNING
  end

  # Get the default model for a mode
  def self.default_model(research_mode: false)
    if research_mode
      "gpt-5"
    else
      "gpt-5-mini"
    end
  end

  # Get the API method/endpoint for a model
  def self.model_to_method(model, force_chat_completions: false)
    spec = MODEL_SPECS[model]

    if spec.nil?
      puts ""
      puts "============================================================="
      if RESPONSES_API_ONLY_MODELS.include?(model)
        puts "Model #{model} requires the Responses API."
        puts "Responses API is now supported in Monadic Chat CLI."
        puts "However, this specific model may not be available yet."
      else
        puts "Model #{model} not found."
        puts "Maybe you are trying to use a model not available any more."
        puts "Check your monadic_chat.conf and try again."
      end
      puts "============================================================="
      puts ""
      exit 1
    end

    api = spec["api_type"] || API_CHAT_COMPLETIONS

    # Allow forcing Chat Completions API for models that might support it
    if force_chat_completions && api == API_RESPONSES
      # Only GPT-5 series supports fallback to Chat Completions
      if model.start_with?("gpt-5")
        return API_CHAT_COMPLETIONS
      end
    end

    api
  end

  # Get available models list
  def self.available_models
    MODEL_SPECS.keys
  end

  # Get max output tokens for a model
  def self.max_output_tokens(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["max_output_tokens"]

    tokens = spec["max_output_tokens"]
    tokens.is_a?(Array) ? tokens[1] : tokens
  end

  # Get context window size for a model
  def self.context_window(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["context_window"]

    window = spec["context_window"]
    window.is_a?(Array) ? window[1] : window
  end

  # Check if a model supports verbosity parameter
  def self.supports_verbosity?(model)
    spec = MODEL_SPECS[model]
    spec && spec["verbosity"]
  end

  # Get available verbosity values for a model
  # Format in models.json: [["available_values"], "default_value"]
  def self.available_verbosities(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["verbosity"]

    verbosity = spec["verbosity"]
    verbosity.is_a?(Array) && verbosity[0].is_a?(Array) ? verbosity[0] : nil
  end

  # Get the default verbosity for a model
  # Returns nil for models that don't support verbosity
  def self.default_verbosity(model)
    spec = MODEL_SPECS[model]
    return nil unless spec && spec["verbosity"]

    verbosity = spec["verbosity"]
    verbosity.is_a?(Array) && verbosity.size >= 2 ? verbosity[1] : "medium"
  end
end
