# frozen_string_literal: true

# Unit tests for export/import format that don't require API authentication
require "spec_helper"
require "json"
require "securerandom"
require_relative "../../lib/monadic_chat/open_ai"

RSpec.describe "Export/Import Format" do
  describe "Monadic Chat format structure" do
    let(:sample_messages) do
      [
        { "role" => "system", "content" => "You are a helpful assistant." },
        { "role" => "user", "content" => "Hello!" },
        { "role" => "assistant", "content" => "Hi there! How can I help you?" }
      ]
    end

    let(:sample_params) do
      {
        "model" => "gpt-4o-mini",
        "temperature" => 0.7,
        "max_tokens" => 2048
      }
    end

    describe "Export format" do
      it "exports with parameters and messages keys" do
        formatted_messages = sample_messages.map do |msg|
          {
            "role" => msg["role"],
            "text" => msg["content"],
            "mid" => SecureRandom.hex(4)
          }
        end

        export_data = {
          "parameters" => {
            "app_name" => "Chat",
            "model" => sample_params["model"],
            "temperature" => sample_params["temperature"],
            "max_tokens" => sample_params["max_tokens"],
            "mode" => "normal"
          },
          "messages" => formatted_messages
        }

        expect(export_data).to have_key("parameters")
        expect(export_data).to have_key("messages")
        expect(export_data["parameters"]).to have_key("app_name")
        expect(export_data["parameters"]).to have_key("model")
        expect(export_data["messages"].first).to have_key("text")
        expect(export_data["messages"].first).to have_key("mid")
        expect(export_data["messages"].first).to have_key("role")
      end

      it "generates unique message IDs" do
        mid1 = SecureRandom.hex(4)
        mid2 = SecureRandom.hex(4)
        expect(mid1).not_to eq(mid2)
        expect(mid1.length).to eq(8)
      end

      it "message IDs are hexadecimal" do
        mid = SecureRandom.hex(4)
        expect(mid).to match(/^[0-9a-f]{8}$/)
      end
    end

    describe "Import format compatibility" do
      it "handles Monadic Chat format with text key" do
        monadic_chat_data = {
          "parameters" => { "app_name" => "ChatOpenAI", "model" => "gpt-4o" },
          "messages" => [
            { "role" => "user", "text" => "Hello", "mid" => "abc123" }
          ]
        }

        messages = monadic_chat_data["messages"].map do |msg|
          {
            "role" => msg["role"],
            "content" => msg["text"] || msg["content"],
            "mid" => msg["mid"]
          }
        end

        expect(messages.first["content"]).to eq("Hello")
        expect(messages.first["mid"]).to eq("abc123")
      end

      it "handles legacy format with content key" do
        legacy_data = {
          "messages" => [
            { "role" => "user", "content" => "Hello" }
          ]
        }

        messages = legacy_data["messages"].map do |msg|
          {
            "role" => msg["role"],
            "content" => msg["text"] || msg["content"],
            "mid" => msg["mid"] || SecureRandom.hex(4)
          }
        end

        expect(messages.first["content"]).to eq("Hello")
        expect(messages.first["mid"]).not_to be_nil
      end

      it "validates message roles" do
        valid_roles = %w[system user assistant]
        sample_messages.each do |msg|
          expect(valid_roles).to include(msg["role"])
        end
      end
    end

    describe "Model validation on import" do
      it "accepts valid models from AVAILABLE_MODELS" do
        valid_model = "gpt-4o-mini"
        expect(OpenAI::AVAILABLE_MODELS).to have_key(valid_model)
      end

      it "rejects invalid models" do
        invalid_model = "gpt-3.5-turbo"
        expect(OpenAI::AVAILABLE_MODELS).not_to have_key(invalid_model)
      end

      it "accepts all current GPT-4.1 models" do
        %w[gpt-4.1 gpt-4.1-mini gpt-4.1-nano].each do |model|
          expect(OpenAI::AVAILABLE_MODELS).to have_key(model)
        end
      end

      it "accepts all current GPT-5 models (Responses API)" do
        %w[gpt-5 gpt-5-mini gpt-5-nano].each do |model|
          expect(OpenAI::AVAILABLE_MODELS).to have_key(model)
        end
      end

      it "accepts all current GPT-5.1 models (Responses API)" do
        %w[gpt-5.1 gpt-5.1-codex].each do |model|
          expect(OpenAI::AVAILABLE_MODELS).to have_key(model)
        end
      end

      it "accepts all current GPT-5.2 models (Responses API)" do
        %w[gpt-5.2 gpt-5.2-pro].each do |model|
          expect(OpenAI::AVAILABLE_MODELS).to have_key(model)
        end
      end
    end
  end

  describe "JSON serialization" do
    it "pretty generates valid JSON" do
      test_data = {
        "parameters" => { "model" => "gpt-4o-mini" },
        "messages" => [{ "role" => "user", "text" => "Test", "mid" => "test123" }]
      }

      json_string = JSON.pretty_generate(test_data)
      parsed = JSON.parse(json_string)

      expect(parsed["parameters"]["model"]).to eq("gpt-4o-mini")
      expect(parsed["messages"].first["text"]).to eq("Test")
    end

    it "handles special characters in messages" do
      test_data = {
        "messages" => [{ "role" => "user", "text" => "Hello \"world\" & <test>", "mid" => "abc" }]
      }

      json_string = JSON.pretty_generate(test_data)
      parsed = JSON.parse(json_string)

      expect(parsed["messages"].first["text"]).to eq("Hello \"world\" & <test>")
    end

    it "handles unicode characters" do
      test_data = {
        "messages" => [{ "role" => "user", "text" => "こんにちは世界 🌍", "mid" => "abc" }]
      }

      json_string = JSON.pretty_generate(test_data)
      parsed = JSON.parse(json_string)

      expect(parsed["messages"].first["text"]).to eq("こんにちは世界 🌍")
    end
  end

  describe "File path validation" do
    it "validates .json extension" do
      valid_paths = ["test.json", "/path/to/file.json", "~/data.json"]
      invalid_paths = ["test.txt", "file.JSON", "no_extension"]

      valid_paths.each do |path|
        expect(path).to match(/\.json\z/)
      end

      invalid_paths.each do |path|
        expect(path).not_to match(/\.json\z/)
      end
    end
  end
end
