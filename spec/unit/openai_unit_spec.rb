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

    it "version is 0.5.0 or higher" do
      version_parts = MonadicChat::VERSION.split(".").map(&:to_i)
      expect(version_parts[0]).to be >= 0
      expect(version_parts[1]).to be >= 5 if version_parts[0] == 0
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
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.2-mini")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.2-nano")
    end

    it "contains GPT-5.1 series models" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.1")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.1-mini")
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-5.1-nano")
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
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4o-2024-11-20")
    end

    it "contains GPT-4 Turbo" do
      expect(OpenAI::AVAILABLE_MODELS).to include("gpt-4-turbo")
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

    it "does not contain chatgpt-4o-latest (deprecated)" do
      expect(OpenAI::AVAILABLE_MODELS).not_to include("chatgpt-4o-latest")
    end

    it "does not contain gpt-5-codex (Responses API only)" do
      expect(OpenAI::AVAILABLE_MODELS).not_to include("gpt-5-codex")
    end

    it "GPT-5+ models use Responses API" do
      %w[gpt-5 gpt-5-mini gpt-5-nano gpt-5.1 gpt-5.1-mini gpt-5.2 gpt-5.2-mini].each do |model|
        expect(OpenAI::AVAILABLE_MODELS[model]).to eq(OpenAI::API_RESPONSES)
      end
    end

    it "GPT-4 models use Chat Completions API" do
      %w[gpt-4.1 gpt-4.1-mini gpt-4o gpt-4o-mini gpt-4-turbo].each do |model|
        expect(OpenAI::AVAILABLE_MODELS[model]).to eq(OpenAI::API_CHAT_COMPLETIONS)
      end
    end

    it "has exactly 16 models" do
      expect(OpenAI::AVAILABLE_MODELS.size).to eq(16)
    end
  end

  describe "RESPONSES_API_ONLY_MODELS" do
    it "is a frozen array" do
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to be_frozen
    end

    it "contains gpt-5-codex variants" do
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to include("gpt-5-codex")
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to include("gpt-5.1-codex")
      expect(OpenAI::RESPONSES_API_ONLY_MODELS).to include("gpt-5.2-codex")
    end

    it "models are not in AVAILABLE_MODELS" do
      OpenAI::RESPONSES_API_ONLY_MODELS.each do |model|
        expect(OpenAI::AVAILABLE_MODELS).not_to include(model)
      end
    end
  end

  describe "DUAL_API_MODELS" do
    it "is a frozen array" do
      expect(OpenAI::DUAL_API_MODELS).to be_frozen
    end

    it "contains GPT-5 series models" do
      expect(OpenAI::DUAL_API_MODELS).to include("gpt-5")
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

    it "returns false for GPT-4 models" do
      expect(OpenAI.responses_api?("gpt-4o")).to be false
      expect(OpenAI.responses_api?("gpt-4.1")).to be false
    end
  end

  describe ".chat_completions_api?" do
    it "returns true for GPT-4 models" do
      expect(OpenAI.chat_completions_api?("gpt-4o")).to be true
      expect(OpenAI.chat_completions_api?("gpt-4.1")).to be true
    end

    it "returns true for dual-API GPT-5 models (fallback support)" do
      expect(OpenAI.chat_completions_api?("gpt-5")).to be true
      expect(OpenAI.chat_completions_api?("gpt-5.1")).to be true
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

    context "with Chat Completions API models" do
      it "returns chat/completions for gpt-4o-mini" do
        expect(OpenAI.model_to_method("gpt-4o-mini")).to eq("chat/completions")
      end

      it "returns chat/completions for gpt-4.1" do
        expect(OpenAI.model_to_method("gpt-4.1")).to eq("chat/completions")
      end

      it "returns chat/completions for gpt-4o" do
        expect(OpenAI.model_to_method("gpt-4o")).to eq("chat/completions")
      end

      it "returns chat/completions for gpt-4-turbo" do
        expect(OpenAI.model_to_method("gpt-4-turbo")).to eq("chat/completions")
      end
    end

    context "with error cases" do
      it "exits with error for invalid model" do
        expect { OpenAI.model_to_method("invalid-model-name") }.to raise_error(SystemExit)
      end

      it "exits with error for deprecated model" do
        expect { OpenAI.model_to_method("gpt-3.5-turbo") }.to raise_error(SystemExit)
      end

      it "exits with error for Responses API only model (gpt-5-codex)" do
        expect { OpenAI.model_to_method("gpt-5-codex") }.to raise_error(SystemExit)
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

    it "copies compatible parameters" do
      params = {
        "model" => "gpt-5",
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

      it "returns true for gpt-5-ultra-pro" do
        expect(OpenAI.expensive_model?("gpt-5-ultra-pro")).to be true
      end

      it "returns true for o3-pro" do
        expect(OpenAI.expensive_model?("o3-pro")).to be true
      end

      it "returns true for o1-pro" do
        expect(OpenAI.expensive_model?("o1-pro")).to be true
      end

      it "returns true for gpt-5-codex-max" do
        expect(OpenAI.expensive_model?("gpt-5-codex-max")).to be true
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

      it "returns false for gpt-4-turbo" do
        expect(OpenAI.expensive_model?("gpt-4-turbo")).to be false
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
end
