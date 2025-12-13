# frozen_string_literal: true

# Unit tests that don't require API authentication
require "spec_helper"
require_relative "../../lib/monadic_chat/version"
require_relative "../../lib/monadic_chat/open_ai"

RSpec.describe MonadicChat do
  describe "VERSION" do
    it "has a version number" do
      expect(MonadicChat::VERSION).not_to be nil
    end

    it "version is 0.6.0 or higher" do
      version_parts = MonadicChat::VERSION.split(".").map(&:to_i)
      expect(version_parts[0]).to be >= 0
      expect(version_parts[1]).to be >= 6 if version_parts[0] == 0
    end

    it "version matches semver format" do
      expect(MonadicChat::VERSION).to match(/^\d+\.\d+\.\d+$/)
    end
  end
end

RSpec.describe OpenAI do
  describe ".default_model" do
    it "returns gpt-5-mini for normal mode" do
      expect(OpenAI.default_model(research_mode: false)).to eq("gpt-5-mini")
    end

    it "returns gpt-5 for research mode" do
      expect(OpenAI.default_model(research_mode: true)).to eq("gpt-5")
    end
  end

  describe "AVAILABLE_MODELS" do
    it "is a frozen hash" do
      expect(OpenAI::AVAILABLE_MODELS).to be_frozen
    end

    it "contains GPT-5.2 series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.2")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.2-pro")
    end

    it "contains GPT-5.1 series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.1")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.1-codex")
    end

    it "contains GPT-5 series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5-mini")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5-nano")
    end

    it "contains GPT-4.1 series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4.1")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4.1-mini")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4.1-nano")
    end

    it "contains GPT-4o series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4o")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4o-mini")
    end

    it "contains O-series reasoning models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("o1")
      expect(OpenAI::AVAILABLE_MODELS).to include("o3")
      expect(OpenAI::AVAILABLE_MODELS).to include("o3-mini")
      expect(OpenAI::AVAILABLE_MODELS).to include("o4-mini")
    end

    it "does not contain deprecated GPT-3.5 models" do
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-3.5-turbo")
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-3.5-turbo-16k")
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-3.5-turbo-0125")
    end

    it "does not contain deprecated GPT-4 preview models" do
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-4-turbo-preview")
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-4-1106-preview")
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-4-0125-preview")
    end

    it "GPT-5+ models use Responses API" do
      %w[gpt-5 gpt-5-mini gpt-5-nano gpt-5.1 gpt-5.2].each do |model|
        expect(OpenAI::AVAILABLE_MODELS[model]).to eq(OpenAI::API_RESPONSES)
      end
    end

    it "GPT-4.1 models use Responses API" do
      %w[gpt-4.1 gpt-4.1-mini gpt-4.1-nano].each do |model|
        expect(OpenAI::AVAILABLE_MODELS[model]).to eq(OpenAI::API_RESPONSES)
      end
    end

    it "GPT-4o models use Chat Completions API" do
      %w[gpt-4o gpt-4o-mini].each do |model|
        expect(OpenAI::AVAILABLE_MODELS[model]).to eq(OpenAI::API_CHAT_COMPLETIONS)
      end
    end

    it "has 30 or more models" do
      expect(OpenAI::AVAILABLE_MODELS.size).to be >= 30
    end
  end

  describe "RESPONSES_API_ONLY_MODELS" do
    it "is a frozen array" do
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to be_frozen
    end

    it "contains agent/codex models" do
      # These are models with is_agent_model: true
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to include("gpt-5-codex")
    end
  end

  describe "DUAL_API_MODELS" do
    it "is a frozen array" do
      expect(OpenAI::DUAL_API_MODELS).to be_frozen
    end

    it "contains GPT-5 series models" do
      expect(OpenAI::DUAL_API_MODELS).to include("gpt-5")
      expect(OpenAI::DUAL_API_MODELS).to include("gpt-5-mini")
      expect(OpenAI::DUAL_API_MODELS).to include("gpt-5.1")
      expect(OpenAI::DUAL_API_MODELS).to include("gpt-5.2")
    end
  end

  describe ".responses_api?" do
    it "returns true for GPT-5 models" do
      expect(OpenAI.responses_api?("gpt-5")).to be true
      expect(OpenAI.responses_api?("gpt-5.1")).to be true
      expect(OpenAI.responses_api?("gpt-5.2")).to be true
    end

    it "returns true for GPT-4.1 models" do
      expect(OpenAI.responses_api?("gpt-4.1")).to be true
      expect(OpenAI.responses_api?("gpt-4.1-mini")).to be true
    end

    it "returns false for GPT-4o models" do
      expect(OpenAI.responses_api?("gpt-4o")).to be false
      expect(OpenAI.responses_api?("gpt-4o-mini")).to be false
    end
  end

  describe ".chat_completions_api?" do
    it "returns true for GPT-4o models" do
      expect(OpenAI.chat_completions_api?("gpt-4o")).to be true
      expect(OpenAI.chat_completions_api?("gpt-4o-mini")).to be true
    end

    it "returns false for GPT-4.1 models (Responses API)" do
      expect(OpenAI.chat_completions_api?("gpt-4.1")).to be false
    end

    it "returns false for GPT-5 models (Responses API)" do
      expect(OpenAI.chat_completions_api?("gpt-5")).to be false
      expect(OpenAI.chat_completions_api?("gpt-5.1")).to be false
    end
  end

  describe ".model_to_method" do
    context "with Responses API models" do
      it "returns responses for gpt-5" do
        expect(OpenAI.model_to_method("gpt-5")).to eq("responses")
      end

      it "returns responses for gpt-5.1" do
        expect(OpenAI.model_to_method("gpt-5.1")).to eq("responses")
      end

      it "returns responses for gpt-5.2" do
        expect(OpenAI.model_to_method("gpt-5.2")).to eq("responses")
      end
    end

    context "with force_chat_completions for dual-API models" do
      it "returns chat/completions for gpt-5 when forced" do
        expect(OpenAI.model_to_method("gpt-5", force_chat_completions: true)).to eq("chat/completions")
      end

      it "returns chat/completions for gpt-5.2 when forced" do
        expect(OpenAI.model_to_method("gpt-5.2", force_chat_completions: true)).to eq("chat/completions")
      end
    end

    context "with GPT-4.1 models (Responses API)" do
      it "returns responses for gpt-4.1" do
        expect(OpenAI.model_to_method("gpt-4.1")).to eq("responses")
      end

      it "returns responses for gpt-4.1-mini" do
        expect(OpenAI.model_to_method("gpt-4.1-mini")).to eq("responses")
      end
    end

    context "with Chat Completions API models" do
      it "returns chat/completions for gpt-4o-mini" do
        expect(OpenAI.model_to_method("gpt-4o-mini")).to eq("chat/completions")
      end

      it "returns chat/completions for gpt-4o" do
        expect(OpenAI.model_to_method("gpt-4o")).to eq("chat/completions")
      end
    end

    context "with error cases" do
      it "exits with error for invalid model" do
        expect {
          # Suppress stdout during this test
          $stdout = StringIO.new
          begin
            OpenAI.model_to_method("invalid-model-name")
          ensure
            $stdout = STDOUT
          end
        }.to raise_error(SystemExit)
      end

      it "exits with error for deprecated model" do
        expect {
          # Suppress stdout during this test
          $stdout = StringIO.new
          begin
            OpenAI.model_to_method("gpt-3.5-turbo")
          ensure
            $stdout = STDOUT
          end
        }.to raise_error(SystemExit)
      end
    end
  end

  describe ".convert_to_responses_format" do
    it "converts simple message to input string" do
      params = {
        "model" => "gpt-5",
        "messages" => [
          { "role" => "user", "content" => "Hello" }
        ]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["input"]).to eq("Hello")
      expect(result["model"]).to eq("gpt-5")
    end

    it "extracts system message as instructions" do
      params = {
        "model" => "gpt-5",
        "messages" => [
          { "role" => "system", "content" => "You are helpful" },
          { "role" => "user", "content" => "Hello" }
        ]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["instructions"]).to eq("You are helpful")
      expect(result["input"]).to eq("Hello")
    end

    it "converts multi-turn conversation to array input" do
      params = {
        "model" => "gpt-5",
        "messages" => [
          { "role" => "user", "content" => "Hello" },
          { "role" => "assistant", "content" => "Hi!" },
          { "role" => "user", "content" => "How are you?" }
        ]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["input"]).to be_an(Array)
      expect(result["input"].size).to eq(3)
    end

    it "copies compatible parameters for non-reasoning models" do
      params = {
        "model" => "gpt-4.1",
        "messages" => [{ "role" => "user", "content" => "Hello" }],
        "stream" => true,
        "temperature" => 0.7,
        "max_tokens" => 1000
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["stream"]).to be true
      expect(result["temperature"]).to eq(0.7)
      expect(result["max_output_tokens"]).to eq(1000)
    end

    it "excludes temperature/top_p for reasoning models (gpt-5)" do
      params = {
        "model" => "gpt-5",
        "messages" => [{ "role" => "user", "content" => "Hello" }],
        "stream" => true,
        "temperature" => 0.7,
        "top_p" => 0.9,
        "max_tokens" => 1000
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["stream"]).to be true
      expect(result["max_output_tokens"]).to eq(1000)
      expect(result).not_to have_key("temperature")
      expect(result).not_to have_key("top_p")
    end

    it "uses system message as input when no user messages (Research mode)" do
      # Research mode sends only a system message containing the full template
      params = {
        "model" => "gpt-5",
        "messages" => [
          { "role" => "system", "content" => "Full template with system prompt and user input" }
        ]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["input"]).to eq("Full template with system prompt and user input")
      expect(result).not_to have_key("instructions")
    end

    it "sets reasoning effort from model default for gpt-5 (minimal)" do
      params = {
        "model" => "gpt-5",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["reasoning"]).to eq({ "effort" => "minimal" })
    end

    it "sets reasoning effort from model default for gpt-5.1 (none)" do
      params = {
        "model" => "gpt-5.1",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["reasoning"]).to eq({ "effort" => "none" })
    end

    it "allows custom reasoning effort override" do
      params = {
        "model" => "gpt-5",
        "messages" => [{ "role" => "user", "content" => "Hello" }],
        "reasoning_effort" => "medium"
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result["reasoning"]).to eq({ "effort" => "medium" })
    end

    it "does not set reasoning for non-reasoning models" do
      params = {
        "model" => "gpt-4.1",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
      result = OpenAI.convert_to_responses_format(params)
      expect(result).not_to have_key("reasoning")
    end

    context "with structured output" do
      it "adds text parameter with format for Responses API" do
        params = {
          "model" => "gpt-5",
          "messages" => [{ "role" => "user", "content" => "Hello" }]
        }
        structured_output = {
          "format" => {
            "type" => "json_schema",
            "name" => "test_schema",
            "schema" => { "type" => "object" },
            "strict" => true
          }
        }
        result = OpenAI.convert_to_responses_format(params, structured_output: structured_output)

        expect(result).to have_key("text")
        expect(result["text"]["format"]["type"]).to eq("json_schema")
        expect(result["text"]["format"]["name"]).to eq("test_schema")
        expect(result["text"]["format"]["strict"]).to be true
      end

      it "does not add format to text parameter when structured_output is nil" do
        params = {
          "model" => "gpt-5",
          "messages" => [{ "role" => "user", "content" => "Hello" }]
        }
        result = OpenAI.convert_to_responses_format(params, structured_output: nil)

        # text parameter may still exist for verbosity, but format should not be present
        if result.key?("text")
          expect(result["text"]).not_to have_key("format")
        end
      end

      it "does not add format to text parameter when structured_output has no format key" do
        params = {
          "model" => "gpt-5",
          "messages" => [{ "role" => "user", "content" => "Hello" }]
        }
        result = OpenAI.convert_to_responses_format(params, structured_output: { "other" => "value" })

        # text parameter may still exist for verbosity, but format should not be present
        if result.key?("text")
          expect(result["text"]).not_to have_key("format")
        end
      end
    end
  end

  describe "EXPENSIVE_MODEL_PATTERNS" do
    it "is a frozen array" do
      expect(OpenAI::EXPENSIVE_MODEL_PATTERNS).to be_frozen
    end

    it "contains patterns for GPT-5 Pro variants" do
      expect(OpenAI::EXPENSIVE_MODEL_PATTERNS.any? { |p| p.match?("gpt-5-pro") }).to be true
      expect(OpenAI::EXPENSIVE_MODEL_PATTERNS.any? { |p| p.match?("gpt-5.2-pro") }).to be true
    end

    it "contains pattern for o3-pro" do
      expect(OpenAI::EXPENSIVE_MODEL_PATTERNS.any? { |p| p.match?("o3-pro") }).to be true
    end

    it "contains pattern for o1-pro" do
      expect(OpenAI::EXPENSIVE_MODEL_PATTERNS.any? { |p| p.match?("o1-pro") }).to be true
    end
  end

  describe ".expensive_model?" do
    context "with expensive models" do
      it "returns true for gpt-5-pro" do
        expect(OpenAI.expensive_model?("gpt-5-pro")).to be true
      end

      it "returns true for gpt-5.2-pro" do
        expect(OpenAI.expensive_model?("gpt-5.2-pro")).to be true
      end

      it "returns true for o3-pro" do
        expect(OpenAI.expensive_model?("o3-pro")).to be true
      end

      it "returns true for o1-pro" do
        expect(OpenAI.expensive_model?("o1-pro")).to be true
      end

      it "is case insensitive" do
        expect(OpenAI.expensive_model?("GPT-5-PRO")).to be true
        expect(OpenAI.expensive_model?("O3-PRO")).to be true
      end
    end

    context "with non-expensive models" do
      it "returns false for gpt-4o" do
        expect(OpenAI.expensive_model?("gpt-4o")).to be false
      end

      it "returns false for gpt-4o-mini" do
        expect(OpenAI.expensive_model?("gpt-4o-mini")).to be false
      end

      it "returns false for gpt-4.1" do
        expect(OpenAI.expensive_model?("gpt-4.1")).to be false
      end

      it "returns false for gpt-4.1-mini" do
        expect(OpenAI.expensive_model?("gpt-4.1-mini")).to be false
      end

      it "returns false for gpt-5 (base, not pro)" do
        expect(OpenAI.expensive_model?("gpt-5")).to be false
      end

      it "returns false for gpt-5-mini" do
        expect(OpenAI.expensive_model?("gpt-5-mini")).to be false
      end
    end
  end

  describe ".expensive_model_warning" do
    it "returns a warning string" do
      warning = OpenAI.expensive_model_warning("gpt-5-pro")
      expect(warning).to be_a(String)
    end

    it "includes the model name in the warning" do
      warning = OpenAI.expensive_model_warning("gpt-5.2-pro")
      expect(warning).to include("gpt-5.2-pro")
    end

    it "includes cost warning" do
      warning = OpenAI.expensive_model_warning("gpt-5-pro")
      expect(warning).to match(/cost/i)
    end

    it "includes warning header" do
      warning = OpenAI.expensive_model_warning("gpt-5-pro")
      expect(warning).to include("WARNING")
    end
  end

  describe ".supports_temperature?" do
    it "returns false for reasoning models (gpt-5)" do
      expect(OpenAI.supports_temperature?("gpt-5")).to be false
      expect(OpenAI.supports_temperature?("gpt-5-mini")).to be false
    end

    it "returns true for gpt-4.1 models" do
      expect(OpenAI.supports_temperature?("gpt-4.1")).to be true
      expect(OpenAI.supports_temperature?("gpt-4.1-mini")).to be true
    end

    it "returns true for gpt-4o models" do
      expect(OpenAI.supports_temperature?("gpt-4o")).to be true
      expect(OpenAI.supports_temperature?("gpt-4o-mini")).to be true
    end
  end

  describe ".default_reasoning_effort" do
    it "returns default effort for gpt-5 (minimal)" do
      expect(OpenAI.default_reasoning_effort("gpt-5")).to eq("minimal")
    end

    it "returns default effort for gpt-5.1 (none)" do
      expect(OpenAI.default_reasoning_effort("gpt-5.1")).to eq("none")
    end

    it "returns default effort for gpt-5.2 (none)" do
      expect(OpenAI.default_reasoning_effort("gpt-5.2")).to eq("none")
    end

    it "returns nil for non-reasoning models" do
      expect(OpenAI.default_reasoning_effort("gpt-4.1")).to be_nil
      expect(OpenAI.default_reasoning_effort("gpt-4o")).to be_nil
    end
  end

  describe ".available_reasoning_efforts" do
    it "returns available efforts for gpt-5" do
      efforts = OpenAI.available_reasoning_efforts("gpt-5")
      expect(efforts).to include("low", "medium", "high")
    end

    it "returns available efforts for gpt-5.1 including none" do
      efforts = OpenAI.available_reasoning_efforts("gpt-5.1")
      expect(efforts).to include("none", "low", "medium", "high")
    end

    it "returns nil for non-reasoning models" do
      expect(OpenAI.available_reasoning_efforts("gpt-4.1")).to be_nil
    end
  end

  describe ".max_output_tokens" do
    it "returns max tokens for gpt-5" do
      expect(OpenAI.max_output_tokens("gpt-5")).to eq(128000)
    end

    it "returns nil for unknown model" do
      expect(OpenAI.max_output_tokens("unknown-model")).to be_nil
    end
  end

  describe ".context_window" do
    it "returns context window for gpt-5" do
      expect(OpenAI.context_window("gpt-5")).to eq(400000)
    end

    it "returns nil for unknown model" do
      expect(OpenAI.context_window("unknown-model")).to be_nil
    end
  end

  describe ".supports_verbosity?" do
    it "returns truthy for gpt-5 models" do
      expect(OpenAI.supports_verbosity?("gpt-5")).to be_truthy
      expect(OpenAI.supports_verbosity?("gpt-5-mini")).to be_truthy
    end

    it "returns truthy for gpt-5.1 models" do
      expect(OpenAI.supports_verbosity?("gpt-5.1")).to be_truthy
    end

    it "returns truthy for gpt-5.2 models" do
      expect(OpenAI.supports_verbosity?("gpt-5.2")).to be_truthy
    end

    it "returns falsey for gpt-4o models" do
      expect(OpenAI.supports_verbosity?("gpt-4o")).to be_falsey
    end

    it "returns falsey for gpt-4.1 models" do
      expect(OpenAI.supports_verbosity?("gpt-4.1")).to be_falsey
    end
  end

  describe ".available_verbosities" do
    it "returns full options for gpt-5" do
      verbosities = OpenAI.available_verbosities("gpt-5")
      expect(verbosities).to be_an(Array)
      expect(verbosities).to include("low", "medium", "high")
    end

    it "returns limited options for gpt-5.2-chat-latest" do
      verbosities = OpenAI.available_verbosities("gpt-5.2-chat-latest")
      expect(verbosities).to eq(["medium"])
    end

    it "returns nil for models that don't support verbosity" do
      expect(OpenAI.available_verbosities("gpt-4o")).to be_nil
    end
  end

  describe ".default_verbosity" do
    it "returns medium for gpt-5" do
      expect(OpenAI.default_verbosity("gpt-5")).to eq("medium")
    end

    it "returns nil for gpt-5-pro (pro models don't support verbosity)" do
      expect(OpenAI.default_verbosity("gpt-5-pro")).to be_nil
    end

    it "returns nil for models that don't support verbosity" do
      expect(OpenAI.default_verbosity("gpt-4o")).to be_nil
    end
  end

  describe "verbosity in convert_to_responses_format" do
    it "includes verbosity for models that support it" do
      params = {
        "model" => "gpt-5",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
      result = OpenAI.convert_to_responses_format(params)

      expect(result).to have_key("text")
      expect(result["text"]["verbosity"]).to eq("medium")
    end

    it "uses custom verbosity when provided" do
      params = {
        "model" => "gpt-5",
        "messages" => [{ "role" => "user", "content" => "Hello" }],
        "verbosity" => "low"
      }
      result = OpenAI.convert_to_responses_format(params)

      expect(result["text"]["verbosity"]).to eq("low")
    end

    it "does not include verbosity for models that don't support it" do
      params = {
        "model" => "gpt-4o",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
      result = OpenAI.convert_to_responses_format(params)

      # gpt-4o doesn't support verbosity, so text should not have verbosity key
      if result.key?("text")
        expect(result["text"]).not_to have_key("verbosity")
      end
    end
  end
end
