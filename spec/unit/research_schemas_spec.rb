# frozen_string_literal: true

# Unit tests for Research Mode Structured Output schemas
require "spec_helper"
require_relative "../../lib/monadic_chat/research_schemas"

RSpec.describe MonadicChat do
  describe "RESEARCH_SCHEMAS" do
    it "is a frozen hash" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to be_frozen
    end

    it "contains schema for chat app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("chat")
    end

    it "contains schema for code app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("code")
    end

    it "contains schema for novel app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("novel")
    end

    it "contains schema for translate app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("translate")
    end

    it "contains schema for wikipedia app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("wikipedia")
    end

    it "contains schema for linguistic app" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("linguistic")
    end

    it "contains default fallback schema" do
      expect(MonadicChat::RESEARCH_SCHEMAS).to have_key("default")
    end

    describe "chat schema" do
      let(:schema) { MonadicChat::RESEARCH_SCHEMAS["chat"] }

      it "has required fields" do
        expect(schema["name"]).to eq("chat_response")
        expect(schema["strict"]).to be true
        expect(schema["schema"]["type"]).to eq("object")
      end

      it "has required properties" do
        properties = schema["schema"]["properties"]
        expect(properties).to have_key("mode")
        expect(properties).to have_key("response")
        expect(properties).to have_key("summary")
        expect(properties).to have_key("language")
        expect(properties).to have_key("topics")
        expect(properties).to have_key("confidence")
        expect(properties).to have_key("ambiguity")
      end

      it "has correct required array" do
        required = schema["schema"]["required"]
        expect(required).to include("mode", "response", "summary", "language", "topics", "confidence", "ambiguity")
      end

      it "has additionalProperties set to false" do
        expect(schema["schema"]["additionalProperties"]).to be false
      end
    end

    describe "translate schema" do
      let(:schema) { MonadicChat::RESEARCH_SCHEMAS["translate"] }

      it "has dictionary property with additionalProperties" do
        dictionary = schema["schema"]["properties"]["dictionary"]
        expect(dictionary["type"]).to eq("object")
        expect(dictionary["additionalProperties"]).to eq({ "type" => "string" })
      end
    end

    describe "linguistic schema" do
      let(:schema) { MonadicChat::RESEARCH_SCHEMAS["linguistic"] }

      it "has sentence_type with enum" do
        sentence_type = schema["schema"]["properties"]["sentence_type"]
        expect(sentence_type["type"]).to eq("array")
        expect(sentence_type["items"]["enum"]).to include("declarative", "interrogative", "imperative", "exclamatory")
      end
    end
  end

  describe ".research_schema" do
    it "returns schema for known app" do
      schema = MonadicChat.research_schema("chat")
      expect(schema).not_to be_nil
      expect(schema["name"]).to eq("chat_response")
    end

    it "returns default schema for unknown app" do
      schema = MonadicChat.research_schema("unknown_app")
      expect(schema).not_to be_nil
      expect(schema["name"]).to eq("default_response")
    end
  end

  describe ".research_schema_for_responses_api" do
    it "returns correct format for Responses API" do
      result = MonadicChat.research_schema_for_responses_api("chat")

      expect(result).to have_key("format")
      expect(result["format"]["type"]).to eq("json_schema")
      expect(result["format"]["name"]).to eq("chat_response")
      expect(result["format"]["strict"]).to be true
      expect(result["format"]["schema"]).to be_a(Hash)
    end

    it "uses default schema for unknown app" do
      result = MonadicChat.research_schema_for_responses_api("custom_app")

      expect(result["format"]["name"]).to eq("default_response")
    end
  end

  describe ".research_schema_for_chat_completions_api" do
    it "returns correct format for Chat Completions API" do
      result = MonadicChat.research_schema_for_chat_completions_api("chat")

      expect(result).to have_key("type")
      expect(result["type"]).to eq("json_schema")
      expect(result).to have_key("json_schema")
      expect(result["json_schema"]["name"]).to eq("chat_response")
      expect(result["json_schema"]["strict"]).to be true
      expect(result["json_schema"]["schema"]).to be_a(Hash)
    end

    it "uses default schema for unknown app" do
      result = MonadicChat.research_schema_for_chat_completions_api("custom_app")

      expect(result["json_schema"]["name"]).to eq("default_response")
    end
  end
end
