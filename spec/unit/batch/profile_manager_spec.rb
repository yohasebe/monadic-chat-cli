# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "yaml"
require_relative "../../../lib/monadic_chat/batch/profile_manager"

RSpec.describe MonadicChat::Batch::ProfileManager do
  let(:test_dir) { Dir.mktmpdir("test_profiles") }
  let(:test_profiles_file) { File.join(test_dir, "batch_profiles.yml") }

  before do
    stub_const("MonadicChat::Batch::ProfileManager::PROFILES_FILE", test_profiles_file)
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe ".init" do
    it "creates profiles file with default profile" do
      expect(File.exist?(test_profiles_file)).to be false

      described_class.init

      expect(File.exist?(test_profiles_file)).to be true

      profiles = YAML.safe_load(File.read(test_profiles_file))
      expect(profiles).to have_key("default")
      expect(profiles["default"]["model"]).to eq("gpt-5-mini")
      expect(profiles["default"]["max_tokens"]).to eq(2000)
    end

    it "does not overwrite existing file" do
      FileUtils.mkdir_p(test_dir)
      File.write(test_profiles_file, { "custom" => { "model" => "gpt-5" } }.to_yaml)

      described_class.init

      profiles = YAML.safe_load(File.read(test_profiles_file))
      expect(profiles).to have_key("custom")
    end
  end

  describe ".list" do
    it "returns all profiles" do
      profiles = described_class.list

      expect(profiles).to be_a(Hash)
      expect(profiles).to have_key("default")
    end

    it "includes saved profiles" do
      described_class.save("translator", { "model" => "gpt-5", "system_prompt" => "Translate" })

      profiles = described_class.list

      expect(profiles).to have_key("translator")
      expect(profiles["translator"]["model"]).to eq("gpt-5")
    end
  end

  describe ".get" do
    it "returns nil for non-existent profile" do
      result = described_class.get("nonexistent")

      expect(result).to be_nil
    end

    it "returns profile configuration" do
      described_class.save("myprofile", { "model" => "gpt-5.1", "max_tokens" => 3000 })

      result = described_class.get("myprofile")

      expect(result["model"]).to eq("gpt-5.1")
      expect(result["max_tokens"]).to eq(3000)
    end

    it "returns default profile" do
      result = described_class.get("default")

      expect(result).not_to be_nil
      expect(result["model"]).to eq("gpt-5-mini")
    end
  end

  describe ".save" do
    it "creates a new profile" do
      described_class.save("newprofile", {
        "model" => "gpt-5.2",
        "max_tokens" => 4000,
        "system_prompt" => "You are helpful"
      })

      profile = described_class.get("newprofile")

      expect(profile["model"]).to eq("gpt-5.2")
      expect(profile["max_tokens"]).to eq(4000)
      expect(profile["system_prompt"]).to eq("You are helpful")
    end

    it "updates an existing profile" do
      described_class.save("updating", { "model" => "gpt-5" })
      described_class.save("updating", { "model" => "gpt-5.1", "max_tokens" => 5000 })

      profile = described_class.get("updating")

      expect(profile["model"]).to eq("gpt-5.1")
      expect(profile["max_tokens"]).to eq(5000)
    end

    it "normalizes symbol keys to strings" do
      described_class.save("symbolkeys", {
        model: "gpt-5",
        max_tokens: 2500
      })

      profile = described_class.get("symbolkeys")

      expect(profile["model"]).to eq("gpt-5")
      expect(profile["max_tokens"]).to eq(2500)
    end

    it "ignores nil values" do
      described_class.save("nilvalues", {
        "model" => "gpt-5",
        "system_prompt" => nil
      })

      profile = described_class.get("nilvalues")

      expect(profile).to have_key("model")
      expect(profile).not_to have_key("system_prompt")
    end
  end

  describe ".delete" do
    before do
      described_class.save("deletable", { "model" => "gpt-5" })
    end

    it "deletes an existing profile" do
      result = described_class.delete("deletable")

      expect(result).to be true
      expect(described_class.get("deletable")).to be_nil
    end

    it "returns false for non-existent profile" do
      result = described_class.delete("nonexistent")

      expect(result).to be false
    end

    it "cannot delete default profile" do
      result = described_class.delete("default")

      expect(result).to be false
      expect(described_class.get("default")).not_to be_nil
    end
  end

  describe ".exists?" do
    it "returns true for existing profile" do
      described_class.save("exists", { "model" => "gpt-5" })

      expect(described_class.exists?("exists")).to be true
    end

    it "returns false for non-existent profile" do
      expect(described_class.exists?("notexists")).to be false
    end

    it "returns true for default profile" do
      expect(described_class.exists?("default")).to be true
    end
  end

  describe ".get_merged" do
    it "returns default values when profile is nil" do
      result = described_class.get_merged(nil)

      expect(result["model"]).to eq("gpt-5-mini")
      expect(result["max_tokens"]).to eq(2000)
    end

    it "returns default values when profile is empty string" do
      result = described_class.get_merged("")

      expect(result["model"]).to eq("gpt-5-mini")
      expect(result["max_tokens"]).to eq(2000)
    end

    it "merges profile with defaults" do
      described_class.save("partial", { "model" => "gpt-5.1" })

      result = described_class.get_merged("partial")

      expect(result["model"]).to eq("gpt-5.1")
      expect(result["max_tokens"]).to eq(2000) # from defaults
    end

    it "profile values override defaults" do
      described_class.save("full", { "model" => "gpt-5.2", "max_tokens" => 5000 })

      result = described_class.get_merged("full")

      expect(result["model"]).to eq("gpt-5.2")
      expect(result["max_tokens"]).to eq(5000)
    end

    it "returns defaults for non-existent profile" do
      result = described_class.get_merged("nonexistent")

      expect(result["model"]).to eq("gpt-5-mini")
      expect(result["max_tokens"]).to eq(2000)
    end
  end

  describe "error handling" do
    it "handles invalid YAML gracefully" do
      FileUtils.mkdir_p(test_dir)
      File.write(test_profiles_file, "invalid: yaml: content: [")

      # Should not raise, returns default
      expect { described_class.list }.to output(/Warning/).to_stderr
      profiles = described_class.list

      expect(profiles).to have_key("default")
    end
  end
end
