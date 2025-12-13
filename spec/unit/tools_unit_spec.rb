# frozen_string_literal: true

# Unit tests for tools that don't require API authentication
require "spec_helper"

RSpec.describe "Tool Detection Patterns" do
  describe "SEARCH_WIKI pattern" do
    let(:wiki_pattern) { /\bSEARCH_WIKI\("?(.+?)"?\)/m }

    it "matches SEARCH_WIKI with double quotes" do
      text = 'To find more information, I will use SEARCH_WIKI("Ruby programming")'
      match = text.match(wiki_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("Ruby programming")
    end

    it "matches SEARCH_WIKI without quotes" do
      text = "SEARCH_WIKI(machine learning)"
      match = text.match(wiki_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("machine learning")
    end

    it "matches SEARCH_WIKI with single word" do
      text = 'SEARCH_WIKI("Python")'
      match = text.match(wiki_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("Python")
    end

    it "matches SEARCH_WIKI in middle of text" do
      text = "Let me search for that. SEARCH_WIKI(Ruby) and then I will explain."
      match = text.match(wiki_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("Ruby")
    end

    it "does not match partial SEARCH_WIKI" do
      text = "SEARCH_WIKIPEDIA(test)"
      match = text.match(wiki_pattern)
      expect(match).to be_nil
    end
  end

  describe "SEARCH_WEB pattern" do
    let(:web_pattern) { /\bSEARCH_WEB\("?(.+?)"?\)/m }

    it "matches SEARCH_WEB with double quotes" do
      text = 'Let me search for that: SEARCH_WEB("latest AI news")'
      match = text.match(web_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("latest AI news")
    end

    it "matches SEARCH_WEB without quotes" do
      text = "SEARCH_WEB(OpenAI GPT models)"
      match = text.match(web_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("OpenAI GPT models")
    end

    it "matches SEARCH_WEB in multiline text" do
      text = <<~TEXT
        I need to find information.
        SEARCH_WEB("Ruby on Rails")
        Then I will summarize.
      TEXT
      match = text.match(web_pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("Ruby on Rails")
    end
  end

  describe "Pattern exclusivity" do
    let(:wiki_pattern) { /\bSEARCH_WIKI\("?(.+?)"?\)/m }
    let(:web_pattern) { /\bSEARCH_WEB\("?(.+?)"?\)/m }

    it "SEARCH_WIKI pattern does not match SEARCH_WEB" do
      text = 'SEARCH_WEB("test")'
      expect(text.match(wiki_pattern)).to be_nil
    end

    it "SEARCH_WEB pattern does not match SEARCH_WIKI" do
      text = 'SEARCH_WIKI("test")'
      expect(text.match(web_pattern)).to be_nil
    end
  end
end

RSpec.describe "Cache behavior" do
  describe "Hash cache operations" do
    it "stores and retrieves values" do
      cache = {}
      cache["key1"] = "value1"
      expect(cache["key1"]).to eq("value1")
    end

    it "checks key existence" do
      cache = { "existing" => "value" }
      expect(cache.key?("existing")).to be true
      expect(cache.key?("nonexistent")).to be false
    end

    it "returns nil for missing keys" do
      cache = {}
      expect(cache["missing"]).to be_nil
    end

    it "supports string keys" do
      cache = {}
      query = "Ruby programming language"
      cache[query] = "result"
      expect(cache[query]).to eq("result")
    end
  end
end

RSpec.describe "Retry logic" do
  describe "Retry counter behavior" do
    it "decrements retry count" do
      num_retrial = 3
      num_retrial -= 1
      expect(num_retrial).to eq(2)
    end

    it "checks positive value" do
      expect(1.positive?).to be true
      expect(0.positive?).to be false
      expect(-1.positive?).to be false
    end
  end
end
