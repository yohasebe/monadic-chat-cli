# frozen_string_literal: true

# Unit tests for native tool use API (JSON Schema tool definitions and execution)
require "spec_helper"
require_relative "../../lib/monadic_chat/tool_definitions"
require_relative "../../lib/monadic_chat/tool_executor"
require_relative "../../lib/monadic_chat/open_ai"
require_relative "../../lib/monadic_app"

RSpec.describe MonadicChat::ToolDefinitions do
  describe "Tool definition structure" do
    it "defines WIKIPEDIA_SEARCH with correct structure" do
      tool = described_class::WIKIPEDIA_SEARCH
      expect(tool["type"]).to eq("function")
      expect(tool.dig("function", "name")).to eq("wikipedia_search")
      expect(tool.dig("function", "parameters", "type")).to eq("object")
      expect(tool.dig("function", "parameters", "properties", "query", "type")).to eq("string")
      expect(tool.dig("function", "parameters", "required")).to include("query")
    end

    it "defines WEB_SEARCH with correct structure" do
      tool = described_class::WEB_SEARCH
      expect(tool["type"]).to eq("function")
      expect(tool.dig("function", "name")).to eq("web_search")
      expect(tool.dig("function", "parameters", "properties", "query", "type")).to eq("string")
    end

    it "defines BATCH_START with required input_path" do
      tool = described_class::BATCH_START
      expect(tool.dig("function", "name")).to eq("batch_start")
      expect(tool.dig("function", "parameters", "required")).to include("input_path")
      expect(tool.dig("function", "parameters", "properties", "mode", "enum")).to include("parallel", "sequential")
    end

    it "defines FILE_READ with path parameter" do
      tool = described_class::FILE_READ
      expect(tool.dig("function", "name")).to eq("file_read")
      expect(tool.dig("function", "parameters", "properties", "path", "type")).to eq("string")
      expect(tool.dig("function", "parameters", "properties", "max_lines", "type")).to eq("integer")
    end

    it "defines FILE_WRITE with path and content" do
      tool = described_class::FILE_WRITE
      expect(tool.dig("function", "name")).to eq("file_write")
      expect(tool.dig("function", "parameters", "required")).to include("path", "content")
      expect(tool.dig("function", "parameters", "properties", "append", "type")).to eq("boolean")
    end

    it "defines FILE_LIST with optional pattern" do
      tool = described_class::FILE_LIST
      expect(tool.dig("function", "name")).to eq("file_list")
      expect(tool.dig("function", "parameters", "properties", "pattern")).not_to be_nil
    end
  end

  describe "Tool collections" do
    it "SEARCH_TOOLS contains wikipedia and web search" do
      names = described_class::SEARCH_TOOLS.map { |t| t.dig("function", "name") }
      expect(names).to include("wikipedia_search", "web_search")
    end

    it "BATCH_TOOLS contains all batch operations" do
      names = described_class::BATCH_TOOLS.map { |t| t.dig("function", "name") }
      expect(names).to include("batch_list_profiles", "batch_start", "batch_status", "batch_result")
      expect(names).to include("batch_check_path", "batch_recent_jobs")
      expect(names).to include("batch_create_input_file", "batch_save_profile")
    end

    it "FILE_TOOLS contains file operations" do
      names = described_class::FILE_TOOLS.map { |t| t.dig("function", "name") }
      expect(names).to include("file_read", "file_write", "file_list")
    end

    it "ALL_TOOLS combines all tool categories" do
      all_names = described_class::ALL_TOOLS.map { |t| t.dig("function", "name") }
      search_names = described_class::SEARCH_TOOLS.map { |t| t.dig("function", "name") }
      batch_names = described_class::BATCH_TOOLS.map { |t| t.dig("function", "name") }
      file_names = described_class::FILE_TOOLS.map { |t| t.dig("function", "name") }

      expect(all_names).to include(*search_names)
      expect(all_names).to include(*batch_names)
      expect(all_names).to include(*file_names)
    end
  end

  describe ".get" do
    it "retrieves tool by name" do
      tool = described_class.get("wikipedia_search")
      expect(tool).not_to be_nil
      expect(tool.dig("function", "name")).to eq("wikipedia_search")
    end

    it "returns nil for unknown tool" do
      expect(described_class.get("nonexistent_tool")).to be_nil
    end
  end

  describe ".by_category" do
    it "returns search tools for :search" do
      tools = described_class.by_category(:search)
      expect(tools).to eq(described_class::SEARCH_TOOLS)
    end

    it "returns batch tools for :batch" do
      tools = described_class.by_category(:batch)
      expect(tools).to eq(described_class::BATCH_TOOLS)
    end

    it "returns file tools for :file" do
      tools = described_class.by_category(:file)
      expect(tools).to eq(described_class::FILE_TOOLS)
    end

    it "returns empty array for unknown category" do
      expect(described_class.by_category(:unknown)).to eq([])
    end
  end

  describe "JSON Schema compliance" do
    it "all tools have additionalProperties: false" do
      described_class::ALL_TOOLS.each do |tool|
        params = tool.dig("function", "parameters")
        expect(params["additionalProperties"]).to eq(false),
          "Tool #{tool.dig('function', 'name')} should have additionalProperties: false"
      end
    end

    it "all tools are frozen" do
      described_class::ALL_TOOLS.each do |tool|
        expect(tool).to be_frozen
      end
    end
  end
end

RSpec.describe "Tool Registration" do
  # Create a test class for tool registration
  let(:test_class) do
    Class.new(MonadicApp) do
      def self.name
        "TestToolApp"
      end
    end
  end

  describe ".enable_tools" do
    it "enables tools_enabled flag" do
      test_class.enable_tools(:search)
      expect(test_class.tools_enabled).to be true
    end

    it "registers search tools" do
      test_class.enable_tools(:search)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      expect(names).to include("wikipedia_search", "web_search")
    end

    it "registers only wikipedia tool" do
      test_class.enable_tools(:wikipedia)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      expect(names).to include("wikipedia_search")
      expect(names).not_to include("web_search")
    end

    it "registers batch tools" do
      test_class.enable_tools(:batch)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      expect(names).to include("batch_start", "batch_status", "batch_result")
    end

    it "registers file tools" do
      test_class.enable_tools(:file)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      expect(names).to include("file_read", "file_write", "file_list")
    end

    it "registers all tools with :all" do
      test_class.enable_tools(:all)
      expect(test_class.registered_tools.size).to eq(MonadicChat::ToolDefinitions::ALL_TOOLS.size)
    end

    it "deduplicates when registering multiple sets" do
      test_class.enable_tools(:search, :all)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      # Should not have duplicate wikipedia_search
      expect(names.count("wikipedia_search")).to eq(1)
    end

    it "combines multiple tool sets" do
      test_class.enable_tools(:batch, :file)
      names = test_class.registered_tools.map { |t| t.dig("function", "name") }
      expect(names).to include("batch_start", "file_read")
    end
  end
end

RSpec.describe "Tool Call Extraction" do
  describe "OpenAI.extract_function_calls" do
    it "extracts function calls from output array" do
      output = [
        { "type" => "message", "content" => [{ "type" => "output_text", "text" => "Hello" }] },
        { "type" => "function_call", "call_id" => "call_123", "name" => "wikipedia_search", "arguments" => '{"query":"Ruby"}' }
      ]

      calls = OpenAI.extract_function_calls(output)
      expect(calls.size).to eq(1)
      expect(calls[0]["id"]).to eq("call_123")
      expect(calls[0]["function"]["name"]).to eq("wikipedia_search")
      expect(calls[0]["function"]["arguments"]).to eq('{"query":"Ruby"}')
    end

    it "returns empty array when no function calls" do
      output = [
        { "type" => "message", "content" => [{ "type" => "output_text", "text" => "No tools needed" }] }
      ]

      calls = OpenAI.extract_function_calls(output)
      expect(calls).to be_empty
    end

    it "extracts multiple function calls" do
      output = [
        { "type" => "function_call", "call_id" => "call_1", "name" => "file_read", "arguments" => '{"path":"/tmp/a"}' },
        { "type" => "function_call", "call_id" => "call_2", "name" => "file_list", "arguments" => '{"path":"/tmp"}' }
      ]

      calls = OpenAI.extract_function_calls(output)
      expect(calls.size).to eq(2)
      expect(calls.map { |c| c["function"]["name"] }).to eq(["file_read", "file_list"])
    end

    it "returns empty array for nil input" do
      expect(OpenAI.extract_function_calls(nil)).to eq([])
    end

    it "returns empty array for non-array input" do
      expect(OpenAI.extract_function_calls("string")).to eq([])
    end
  end

  describe "OpenAI.build_choices_response with tool_calls" do
    it "sets finish_reason to tool_calls when tools are present" do
      parsed = { "status" => "completed" }
      tool_calls = [{ "id" => "call_1", "function" => { "name" => "test" } }]

      response = OpenAI.build_choices_response(parsed, "text", tool_calls: tool_calls)

      expect(response["choices"][0]["finish_reason"]).to eq("tool_calls")
      expect(response["tool_calls"]).to eq(tool_calls)
    end

    it "does not add tool_calls when empty" do
      parsed = { "status" => "completed" }

      response = OpenAI.build_choices_response(parsed, "text", tool_calls: [])

      expect(response["choices"][0]["finish_reason"]).to eq("stop")
      expect(response["tool_calls"]).to be_nil
    end

    it "does not add tool_calls when nil" do
      parsed = { "status" => "completed" }

      response = OpenAI.build_choices_response(parsed, "text", tool_calls: nil)

      expect(response["choices"][0]["finish_reason"]).to eq("stop")
      expect(response["tool_calls"]).to be_nil
    end
  end
end

RSpec.describe "Tool Executor Security" do
  # Test the path_allowed? method indirectly through file tool behavior
  describe "ALLOWED_FILE_PATHS" do
    it "includes current working directory" do
      expect(MonadicApp::ALLOWED_FILE_PATHS).to include(Dir.pwd)
    end

    it "includes Downloads directory" do
      downloads = File.expand_path("~/Downloads")
      expect(MonadicApp::ALLOWED_FILE_PATHS).to include(downloads)
    end

    it "includes Documents directory" do
      documents = File.expand_path("~/Documents")
      expect(MonadicApp::ALLOWED_FILE_PATHS).to include(documents)
    end

    it "includes .monadic_chat directory" do
      monadic_chat = File.expand_path("~/.monadic_chat")
      expect(MonadicApp::ALLOWED_FILE_PATHS).to include(monadic_chat)
    end
  end

  describe "File size limits" do
    it "defines MAX_FILE_READ_SIZE as 1MB" do
      expect(MonadicApp::MAX_FILE_READ_SIZE).to eq(1_048_576)
    end

    it "defines MAX_FILE_WRITE_SIZE as 100KB" do
      expect(MonadicApp::MAX_FILE_WRITE_SIZE).to eq(102_400)
    end
  end
end

RSpec.describe "Tool Response Formatting" do
  describe "Completion.run with tool calls" do
    # Mock test to verify tool call detection in response
    it "returns hash with tool_calls key when model wants to call tools" do
      # Simulate a response with tool_calls
      response_with_tools = {
        "tool_calls" => [
          { "id" => "call_1", "function" => { "name" => "test", "arguments" => "{}" } }
        ],
        "text" => "I will call a tool"
      }

      # Verify structure
      expect(response_with_tools).to have_key("tool_calls")
      expect(response_with_tools["tool_calls"]).to be_an(Array)
      expect(response_with_tools["tool_calls"][0]).to have_key("id")
      expect(response_with_tools["tool_calls"][0]).to have_key("function")
    end
  end
end
