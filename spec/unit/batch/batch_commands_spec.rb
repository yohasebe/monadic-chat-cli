# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "pastel"

# Create mock PASTEL before requiring batch_commands
module MonadicChat
  PASTEL = Pastel.new(enabled: false) unless defined?(PASTEL)
  PROMPT_SYSTEM = Object.new unless defined?(PROMPT_SYSTEM)
end

require_relative "../../../lib/monadic_chat/batch_commands"

RSpec.describe MonadicChat::BatchCommands do
  let(:test_batches_dir) { Dir.mktmpdir("test_batches") }
  let(:mock_pastel) { Pastel.new(enabled: false) }

  before do
    stub_const("MonadicChat::Batch::JobManager::BATCHES_DIR", test_batches_dir)
    # Mock pastel and prompt_system methods
    allow(described_class).to receive(:pastel).and_return(mock_pastel)
  end

  after do
    FileUtils.rm_rf(test_batches_dir)
  end

  describe ".run" do
    it "shows help for unknown command" do
      expect { described_class.run(["unknown"]) }.to output(/Unknown batch command/).to_stdout
    end

    it "shows help for 'help' command" do
      expect { described_class.run(["help"]) }.to output(/Monadic Chat - Batch Processing/).to_stdout
    end

    it "shows help for nil command" do
      expect { described_class.run([]) }.to output(/Monadic Chat - Batch Processing/).to_stdout
    end

    it "shows help for '-h' flag" do
      expect { described_class.run(["-h"]) }.to output(/Monadic Chat - Batch Processing/).to_stdout
    end
  end

  describe "parse_options" do
    # Access private method for testing
    let(:parse_options) { described_class.send(:parse_options, args) }

    context "with model option" do
      let(:args) { ["--model", "gpt-5"] }

      it "parses model" do
        result = described_class.send(:parse_options, args)
        expect(result[:model]).to eq("gpt-5")
      end
    end

    context "with short model option" do
      let(:args) { ["-m", "gpt-5-mini"] }

      it "parses model" do
        result = described_class.send(:parse_options, args)
        expect(result[:model]).to eq("gpt-5-mini")
      end
    end

    context "with max-tokens option" do
      let(:args) { ["--max-tokens", "4000"] }

      it "parses max_tokens as integer" do
        result = described_class.send(:parse_options, args)
        expect(result[:max_tokens]).to eq(4000)
      end
    end

    context "with system prompt option" do
      let(:args) { ["--system", "You are a translator"] }

      it "parses system_prompt" do
        result = described_class.send(:parse_options, args)
        expect(result[:system_prompt]).to eq("You are a translator")
      end
    end

    context "with output option" do
      let(:args) { ["--output", "./results/"] }

      it "parses output path" do
        result = described_class.send(:parse_options, args)
        expect(result[:output]).to eq("./results/")
      end
    end

    context "with format option" do
      let(:args) { ["--format", "json"] }

      it "parses format" do
        result = described_class.send(:parse_options, args)
        expect(result[:format]).to eq("json")
      end
    end

    context "with status filter" do
      let(:args) { ["--status", "completed"] }

      it "parses status" do
        result = described_class.send(:parse_options, args)
        expect(result[:status]).to eq("completed")
      end
    end

    context "with multiple options" do
      let(:args) { ["-m", "gpt-5", "-t", "3000", "-s", "Be helpful"] }

      it "parses all options" do
        result = described_class.send(:parse_options, args)
        expect(result[:model]).to eq("gpt-5")
        expect(result[:max_tokens]).to eq(3000)
        expect(result[:system_prompt]).to eq("Be helpful")
      end
    end

    context "with profile option" do
      let(:args) { ["--profile", "translator"] }

      it "parses profile" do
        result = described_class.send(:parse_options, args)
        expect(result[:profile]).to eq("translator")
      end
    end

    context "with short profile option" do
      let(:args) { ["-p", "myprofile"] }

      it "parses profile" do
        result = described_class.send(:parse_options, args)
        expect(result[:profile]).to eq("myprofile")
      end
    end
  end

  describe "build_config" do
    let(:test_profiles_dir) { Dir.mktmpdir("test_profiles") }

    before do
      stub_const("MonadicChat::Batch::ProfileManager::PROFILES_FILE",
                 File.join(test_profiles_dir, "batch_profiles.yml"))
    end

    after do
      FileUtils.rm_rf(test_profiles_dir)
    end

    it "uses defaults when no options provided" do
      result = described_class.send(:build_config, {})
      expect(result[:model]).to eq("gpt-5-mini")
      expect(result[:max_tokens]).to eq(2000)
      expect(result[:system_prompt]).to be_nil
    end

    it "uses provided options" do
      options = { model: "gpt-5", max_tokens: 4000, system_prompt: "Test" }
      result = described_class.send(:build_config, options)
      expect(result[:model]).to eq("gpt-5")
      expect(result[:max_tokens]).to eq(4000)
      expect(result[:system_prompt]).to eq("Test")
    end

    it "uses profile settings when profile is specified" do
      MonadicChat::Batch::ProfileManager.save("translator", {
        "model" => "gpt-5.1",
        "max_tokens" => 3000,
        "system_prompt" => "Translate to Japanese"
      })

      result = described_class.send(:build_config, { profile: "translator" })
      expect(result[:model]).to eq("gpt-5.1")
      expect(result[:max_tokens]).to eq(3000)
      expect(result[:system_prompt]).to eq("Translate to Japanese")
    end

    it "command line options override profile settings" do
      MonadicChat::Batch::ProfileManager.save("base", {
        "model" => "gpt-5",
        "max_tokens" => 2500
      })

      options = { profile: "base", model: "gpt-5.2" }
      result = described_class.send(:build_config, options)
      expect(result[:model]).to eq("gpt-5.2") # overridden
      expect(result[:max_tokens]).to eq(2500) # from profile
    end
  end

  describe "estimate_cost" do
    it "estimates cost for gpt-5-mini" do
      cost = described_class.send(:estimate_cost, 100, "gpt-5-mini")
      expect(cost).to be_a(Float)
      expect(cost).to be > 0
    end

    it "estimates higher cost for gpt-5.2" do
      cost_mini = described_class.send(:estimate_cost, 100, "gpt-5-mini")
      cost_52 = described_class.send(:estimate_cost, 100, "gpt-5.2")
      expect(cost_52).to be > cost_mini
    end
  end

  describe "format_status" do
    it "formats completed status in green" do
      result = described_class.send(:format_status, "completed")
      expect(result).to include("completed")
    end

    it "formats failed status in red" do
      result = described_class.send(:format_status, "failed")
      expect(result).to include("failed")
    end

    it "formats in_progress status in yellow" do
      result = described_class.send(:format_status, "in_progress")
      expect(result).to include("in_progress")
    end

    it "returns unknown status as-is" do
      result = described_class.send(:format_status, "unknown")
      expect(result).to eq("unknown")
    end
  end

  describe "format_time" do
    it "formats ISO8601 time" do
      result = described_class.send(:format_time, "2024-12-13T15:30:00Z")
      expect(result).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}/)
    end

    it "returns N/A for nil" do
      result = described_class.send(:format_time, nil)
      expect(result).to eq("N/A")
    end

    it "returns original string for invalid format" do
      result = described_class.send(:format_time, "invalid")
      expect(result).to eq("invalid")
    end
  end

  describe "truncate" do
    it "returns short strings unchanged" do
      result = described_class.send(:truncate, "short", 10)
      expect(result).to eq("short")
    end

    it "truncates long strings with ellipsis" do
      result = described_class.send(:truncate, "this is a long string", 10)
      expect(result).to eq("this is...")
      expect(result.length).to eq(10)
    end

    it "handles nil" do
      result = described_class.send(:truncate, nil, 10)
      expect(result).to be_nil
    end
  end

  describe "cmd_list" do
    before do
      # Create some test jobs
      MonadicChat::Batch::JobManager.create(
        input_path: "/test/input.txt",
        input_type: :text_file,
        record_count: 10,
        config: { "model" => "gpt-5-mini" }
      )
    end

    it "requires authentication" do
      allow(MonadicChat).to receive(:authenticate).and_return(nil)

      expect { described_class.run(["list"]) }.to output(/Authentication failed/).to_stdout
    end
  end

  describe "profile commands" do
    let(:test_profiles_dir) { Dir.mktmpdir("test_profiles") }

    before do
      stub_const("MonadicChat::Batch::ProfileManager::PROFILES_FILE",
                 File.join(test_profiles_dir, "batch_profiles.yml"))
    end

    after do
      FileUtils.rm_rf(test_profiles_dir)
    end

    describe "profile list" do
      it "shows profiles" do
        expect { described_class.run(["profile", "list"]) }.to output(/Batch Profiles/).to_stdout
      end

      it "shows default profile" do
        expect { described_class.run(["profile", "list"]) }.to output(/default/).to_stdout
      end
    end

    describe "profile show" do
      it "requires profile name" do
        expect { described_class.run(["profile", "show"]) }.to output(/Profile name is required/).to_stdout
      end

      it "shows error for non-existent profile" do
        expect { described_class.run(["profile", "show", "nonexistent"]) }.to output(/Profile not found/).to_stdout
      end

      it "shows profile details" do
        MonadicChat::Batch::ProfileManager.save("myprofile", { "model" => "gpt-5" })

        expect { described_class.run(["profile", "show", "myprofile"]) }.to output(/gpt-5/).to_stdout
      end
    end

    describe "profile save" do
      it "requires profile name" do
        expect { described_class.run(["profile", "save"]) }.to output(/Profile name is required/).to_stdout
      end

      it "requires at least one option" do
        expect { described_class.run(["profile", "save", "newprofile"]) }.to output(/At least one option/).to_stdout
      end

      it "rejects non-GPT-5 models" do
        expect { described_class.run(["profile", "save", "badmodel", "-m", "gpt-4o"]) }.to output(/Only GPT-5 series/).to_stdout
      end

      it "cannot modify default profile" do
        expect { described_class.run(["profile", "save", "default", "-m", "gpt-5"]) }.to output(/Cannot modify the default profile/).to_stdout
      end

      it "creates new profile" do
        expect { described_class.run(["profile", "save", "newprofile", "-m", "gpt-5"]) }.to output(/created/).to_stdout

        profile = MonadicChat::Batch::ProfileManager.get("newprofile")
        expect(profile["model"]).to eq("gpt-5")
      end
    end

    describe "profile delete" do
      before do
        MonadicChat::Batch::ProfileManager.save("deletable", { "model" => "gpt-5" })
        allow(described_class).to receive(:prompt_system).and_return(double(yes?: true))
      end

      it "requires profile name" do
        expect { described_class.run(["profile", "delete"]) }.to output(/Profile name is required/).to_stdout
      end

      it "cannot delete default profile" do
        expect { described_class.run(["profile", "delete", "default"]) }.to output(/Cannot delete the default profile/).to_stdout
      end

      it "shows error for non-existent profile" do
        expect { described_class.run(["profile", "delete", "nonexistent"]) }.to output(/Profile not found/).to_stdout
      end
    end
  end
end
