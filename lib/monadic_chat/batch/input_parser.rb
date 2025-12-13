# frozen_string_literal: true

require "csv"

module MonadicChat
  module Batch
    # Parses various input formats into an array of records for batch processing
    class InputParser
      attr_reader :records, :source_type, :source_path

      # Supported file extensions for folder mode
      SUPPORTED_EXTENSIONS = %w[.txt .md .markdown .json .csv .html .xml .yaml .yml].freeze

      def initialize(path)
        @source_path = File.expand_path(path)
        @records = []
        @source_type = detect_type
      end

      # Parse the input and return records
      # Each record is a hash with :id, :content, and :source keys
      def parse
        case @source_type
        when :text_file
          parse_text_file
        when :csv_file
          parse_csv_file
        when :folder
          parse_folder
        else
          raise ArgumentError, "Unsupported input type: #{@source_path}"
        end

        @records
      end

      # Returns the number of records
      def count
        @records.size
      end

      private

      def detect_type
        unless File.exist?(@source_path)
          raise ArgumentError, "Path does not exist: #{@source_path}"
        end

        if File.directory?(@source_path)
          :folder
        elsif @source_path.end_with?(".csv")
          :csv_file
        elsif File.file?(@source_path)
          :text_file
        else
          raise ArgumentError, "Cannot determine input type: #{@source_path}"
        end
      end

      # Parse text file (one record per line)
      def parse_text_file
        lines = File.readlines(@source_path, chomp: true)
        lines.each_with_index do |line, index|
          next if line.strip.empty?

          @records << {
            id: "rec-#{format('%06d', index + 1)}",
            content: line,
            source: File.basename(@source_path),
            line_number: index + 1
          }
        end
      end

      # Parse CSV file
      # Supports: id,content columns OR single column (content only)
      def parse_csv_file
        csv_content = File.read(@source_path)
        csv = CSV.parse(csv_content, headers: true, liberal_parsing: true)

        # Check if headers exist and what format
        if csv.headers.include?("content") || csv.headers.include?("text")
          parse_csv_with_headers(csv)
        else
          # Try parsing without headers
          csv_no_headers = CSV.parse(csv_content, headers: false, liberal_parsing: true)
          parse_csv_without_headers(csv_no_headers)
        end
      end

      def parse_csv_with_headers(csv)
        content_key = csv.headers.include?("content") ? "content" : "text"
        id_key = csv.headers.include?("id") ? "id" : nil

        csv.each_with_index do |row, index|
          content = row[content_key]&.strip
          next if content.nil? || content.empty?

          record_id = if id_key && row[id_key]
                        row[id_key].to_s
                      else
                        "rec-#{format('%06d', index + 1)}"
                      end

          @records << {
            id: record_id,
            content: content,
            source: File.basename(@source_path),
            row_number: index + 1
          }
        end
      end

      def parse_csv_without_headers(csv)
        csv.each_with_index do |row, index|
          # Skip header row if it looks like headers
          next if index.zero? && row[0]&.downcase&.match?(/\A(id|content|text)\z/)

          content = row[0]&.strip
          next if content.nil? || content.empty?

          @records << {
            id: "rec-#{format('%06d', index + 1)}",
            content: content,
            source: File.basename(@source_path),
            row_number: index + 1
          }
        end
      end

      # Parse folder (one file = one record)
      def parse_folder
        files = Dir.glob(File.join(@source_path, "**", "*"))
                   .select { |f| File.file?(f) && supported_file?(f) }
                   .sort

        files.each_with_index do |file_path, index|
          content = File.read(file_path).strip
          next if content.empty?

          relative_path = file_path.sub("#{@source_path}/", "")

          @records << {
            id: "rec-#{format('%06d', index + 1)}",
            content: content,
            source: relative_path,
            file_path: file_path
          }
        end
      end

      def supported_file?(path)
        ext = File.extname(path).downcase
        SUPPORTED_EXTENSIONS.include?(ext)
      end
    end
  end
end
