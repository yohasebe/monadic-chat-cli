# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require_relative "../../../lib/monadic_chat/batch/input_parser"

RSpec.describe MonadicChat::Batch::InputParser do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#parse with text file" do
    let(:text_file) do
      path = File.join(temp_dir, "input.txt")
      File.write(path, "Line one\nLine two\nLine three\n")
      path
    end

    it "parses each line as a record" do
      parser = described_class.new(text_file)
      records = parser.parse

      expect(records.size).to eq(3)
      expect(records[0][:content]).to eq("Line one")
      expect(records[1][:content]).to eq("Line two")
      expect(records[2][:content]).to eq("Line three")
    end

    it "assigns sequential IDs" do
      parser = described_class.new(text_file)
      records = parser.parse

      expect(records[0][:id]).to eq("rec-000001")
      expect(records[1][:id]).to eq("rec-000002")
      expect(records[2][:id]).to eq("rec-000003")
    end

    it "skips empty lines" do
      path = File.join(temp_dir, "with_empty.txt")
      File.write(path, "Line one\n\nLine two\n   \nLine three\n")

      parser = described_class.new(path)
      records = parser.parse

      expect(records.size).to eq(3)
    end

    it "detects source_type as :text_file" do
      parser = described_class.new(text_file)
      expect(parser.source_type).to eq(:text_file)
    end
  end

  describe "#parse with CSV file" do
    context "with id,content headers" do
      let(:csv_file) do
        path = File.join(temp_dir, "input.csv")
        File.write(path, "id,content\ndoc001,\"First document\"\ndoc002,\"Second document\"\n")
        path
      end

      it "parses records with provided IDs" do
        parser = described_class.new(csv_file)
        records = parser.parse

        expect(records.size).to eq(2)
        expect(records[0][:id]).to eq("doc001")
        expect(records[0][:content]).to eq("First document")
        expect(records[1][:id]).to eq("doc002")
        expect(records[1][:content]).to eq("Second document")
      end
    end

    context "with content only header" do
      let(:csv_file) do
        path = File.join(temp_dir, "content_only.csv")
        File.write(path, "content\n\"First document\"\n\"Second document\"\n")
        path
      end

      it "parses records and generates IDs" do
        parser = described_class.new(csv_file)
        records = parser.parse

        expect(records.size).to eq(2)
        expect(records[0][:id]).to eq("rec-000001")
        expect(records[0][:content]).to eq("First document")
      end
    end

    context "with text header (alternative)" do
      let(:csv_file) do
        path = File.join(temp_dir, "text_header.csv")
        File.write(path, "id,text\nid1,\"Content here\"\n")
        path
      end

      it "parses text column as content" do
        parser = described_class.new(csv_file)
        records = parser.parse

        expect(records[0][:content]).to eq("Content here")
      end
    end

    it "detects source_type as :csv_file" do
      path = File.join(temp_dir, "test.csv")
      File.write(path, "content\n\"test\"\n")

      parser = described_class.new(path)
      expect(parser.source_type).to eq(:csv_file)
    end
  end

  describe "#parse with folder" do
    let(:folder) do
      FileUtils.mkdir_p(File.join(temp_dir, "docs"))
      File.write(File.join(temp_dir, "docs", "file1.txt"), "Content of file 1")
      File.write(File.join(temp_dir, "docs", "file2.md"), "Content of file 2")
      File.write(File.join(temp_dir, "docs", "file3.json"), '{"key": "value"}')
      File.join(temp_dir, "docs")
    end

    it "parses each file as a record" do
      parser = described_class.new(folder)
      records = parser.parse

      expect(records.size).to eq(3)
    end

    it "includes file content" do
      parser = described_class.new(folder)
      records = parser.parse

      contents = records.map { |r| r[:content] }
      expect(contents).to include("Content of file 1")
      expect(contents).to include("Content of file 2")
      expect(contents).to include('{"key": "value"}')
    end

    it "records source file path" do
      parser = described_class.new(folder)
      records = parser.parse

      sources = records.map { |r| r[:source] }
      expect(sources).to include("file1.txt")
      expect(sources).to include("file2.md")
    end

    it "ignores unsupported file types" do
      File.write(File.join(folder, "image.png"), "fake image data")
      File.write(File.join(folder, "binary.exe"), "fake binary")

      parser = described_class.new(folder)
      records = parser.parse

      sources = records.map { |r| r[:source] }
      expect(sources).not_to include("image.png")
      expect(sources).not_to include("binary.exe")
    end

    it "detects source_type as :folder" do
      parser = described_class.new(folder)
      expect(parser.source_type).to eq(:folder)
    end

    it "handles nested directories" do
      FileUtils.mkdir_p(File.join(folder, "subdir"))
      File.write(File.join(folder, "subdir", "nested.txt"), "Nested content")

      parser = described_class.new(folder)
      records = parser.parse

      sources = records.map { |r| r[:source] }
      expect(sources).to include("subdir/nested.txt")
    end
  end

  describe "#count" do
    it "returns the number of records after parsing" do
      path = File.join(temp_dir, "count_test.txt")
      File.write(path, "One\nTwo\nThree\n")

      parser = described_class.new(path)
      parser.parse

      expect(parser.count).to eq(3)
    end
  end

  describe "error handling" do
    it "raises error for non-existent path" do
      expect {
        described_class.new("/nonexistent/path")
      }.to raise_error(ArgumentError, /does not exist/)
    end
  end
end
