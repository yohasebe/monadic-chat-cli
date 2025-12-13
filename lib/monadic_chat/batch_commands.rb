# frozen_string_literal: true

require_relative "batch"

module MonadicChat
  # CLI commands for batch processing
  module BatchCommands
    class << self
      def run(args)
        subcommand = args[0]

        case subcommand
        when "start"
          cmd_start(args[1..])
        when "list", "ls"
          cmd_list(args[1..])
        when "status"
          cmd_status(args[1..])
        when "result", "results"
          cmd_result(args[1..])
        when "cancel"
          cmd_cancel(args[1..])
        when "delete", "del", "rm"
          cmd_delete(args[1..])
        when "wait"
          cmd_wait(args[1..])
        when "clean"
          cmd_clean(args[1..])
        when "profile"
          cmd_profile(args[1..])
        when "help", "-h", "--help", nil
          cmd_help
        else
          print_error("Unknown batch command: #{subcommand}")
          cmd_help
        end
      end

      private

      # batch start [INPUT_PATH] [OPTIONS]
      def cmd_start(args)
        input_path = args[0]

        unless input_path
          print_error("Input path is required")
          print_info("Usage: monadic-chat batch start <INPUT_PATH> [OPTIONS]")
          return
        end

        unless File.exist?(input_path)
          print_error("Input path does not exist: #{input_path}")
          return
        end

        # Parse options
        options = parse_options(args[1..])

        # Validate profile if specified
        if options[:profile] && !Batch::ProfileManager.exists?(options[:profile])
          print_error("Profile not found: #{options[:profile]}")
          print_info("Use 'monadic-chat batch profile list' to see available profiles")
          return
        end

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        # Parse input to show preview
        parser = Batch::InputParser.new(input_path)
        records = parser.parse

        print_header("Batch Job Setup")
        puts "Input: #{parser.source_path}"
        puts "Type: #{parser.source_type}"
        puts "Records: #{records.size}"
        puts ""

        # Show sample records
        puts "Sample records:"
        records.first(3).each_with_index do |record, i|
          content_preview = record[:content].to_s[0, 60]
          content_preview += "..." if record[:content].to_s.length > 60
          puts "  #{i + 1}. [#{record[:id]}] #{content_preview}"
        end
        puts "  ..." if records.size > 3
        puts ""

        # Configure
        config = build_config(options)
        puts "Configuration:"
        puts "  Profile: #{options[:profile] || 'default'}"
        puts "  Model: #{config[:model]}"
        puts "  Max tokens: #{config[:max_tokens]}"
        puts "  System prompt: #{config[:system_prompt] ? 'Yes' : 'None'}"
        puts ""

        # Estimate cost (rough)
        estimated_cost = estimate_cost(records.size, config[:model])
        puts "Estimated cost: $#{format('%.2f', estimated_cost)} - $#{format('%.2f', estimated_cost * 2)} (Batch API 50% discount applied)"
        puts ""

        # Confirm
        unless prompt_system.yes?("Start batch job?", default: true)
          print_info("Cancelled")
          return
        end

        # Start the job
        print_info("Starting batch job...")

        begin
          job = processor.start(input_path: input_path, config: config)
          print_success("Batch job created!")
          puts ""
          puts "Job ID: #{pastel.bold(job['job_id'])}"
          puts "OpenAI Batch ID: #{job['openai_batch_id']}"
          puts "Status: #{format_status(job['status'])}"
          puts ""
          puts "Check status: monadic-chat batch status #{job['job_id']}"
          puts "Get results:  monadic-chat batch result #{job['job_id']}"
        rescue StandardError => e
          print_error("Failed to start batch job: #{e.message}")
        end
      end

      # batch list [OPTIONS]
      def cmd_list(args)
        options = parse_options(args)
        status_filter = options[:status]

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)
        jobs = processor.list_jobs(status: status_filter)

        if jobs.empty?
          print_info("No batch jobs found")
          return
        end

        print_header("Batch Jobs")

        # Table format
        puts format("%-30s %-12s %-10s %-12s %-20s",
                    "JOB ID", "STATUS", "PROGRESS", "MODEL", "CREATED")
        puts "-" * 90

        jobs.each do |job|
          progress = "#{job.dig('stats', 'completed')}/#{job.dig('stats', 'total')}"
          model = job.dig('config', 'model') || 'N/A'
          created = format_time(job['created_at'])

          puts format("%-30s %-12s %-10s %-12s %-20s",
                      truncate(job['job_id'], 30),
                      format_status(job['status']),
                      progress,
                      truncate(model, 12),
                      created)
        end

        puts ""
        puts "Total: #{jobs.size} jobs"
      end

      # batch status [JOB_ID]
      def cmd_status(args)
        job_id = args[0]

        unless job_id
          print_error("Job ID is required")
          print_info("Usage: monadic-chat batch status <JOB_ID>")
          return
        end

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        begin
          job = processor.check_status(job_id)

          print_header("Batch Job Status")
          puts "Job ID: #{pastel.bold(job['job_id'])}"
          puts "OpenAI Batch ID: #{job['openai_batch_id'] || 'N/A'}"
          puts "Status: #{format_status(job['status'])}"
          puts "Mode: #{job['mode']}"
          puts ""
          puts "Progress:"
          puts "  Total: #{job.dig('stats', 'total')}"
          puts "  Completed: #{job.dig('stats', 'completed')}"
          puts "  Failed: #{job.dig('stats', 'failed')}"
          puts ""
          puts "Input:"
          puts "  Path: #{job.dig('input', 'path')}"
          puts "  Type: #{job.dig('input', 'type')}"
          puts "  Records: #{job.dig('input', 'record_count')}"
          puts ""
          puts "Config:"
          puts "  Model: #{job.dig('config', 'model')}"
          puts "  Max tokens: #{job.dig('config', 'max_tokens')}"
          puts ""
          puts "Created: #{format_time(job['created_at'])}"
          puts "Updated: #{format_time(job['updated_at'])}"

          if job['errors'] && !job['errors'].empty?
            puts ""
            puts "Errors:"
            job['errors'].each do |error|
              puts "  - #{error['message'] || error}"
            end
          end
        rescue StandardError => e
          print_error("Failed to get status: #{e.message}")
        end
      end

      # batch result [JOB_ID] [OPTIONS]
      def cmd_result(args)
        job_id = args[0]

        unless job_id
          print_error("Job ID is required")
          print_info("Usage: monadic-chat batch result <JOB_ID> [--output PATH] [--format FORMAT]")
          return
        end

        options = parse_options(args[1..])
        output_path = options[:output]
        output_format = options[:format] || "text"

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        begin
          # First check status
          job = processor.check_status(job_id)

          unless job['status'] == 'completed'
            print_error("Job is not completed yet. Status: #{job['status']}")
            print_info("Use 'monadic-chat batch status #{job_id}' to check progress")
            return
          end

          print_info("Retrieving results...")
          results = processor.retrieve_results(job_id)

          success_count = results.count { |r| r[:text] && !r[:error] }
          error_count = results.count { |r| r[:error] }

          print_success("Retrieved #{results.size} results (#{success_count} success, #{error_count} errors)")
          puts ""

          if output_path
            save_results(results, output_path, output_format, job)
          else
            # Display results
            results.each do |result|
              puts "-" * 60
              puts "ID: #{result[:custom_id]}"
              puts "Source: #{result[:source]}" if result[:source]

              if result[:error]
                puts "Error: #{result[:error]['message'] || result[:error]}"
              else
                puts "Response:"
                puts result[:text]
              end
              puts ""
            end
          end
        rescue StandardError => e
          print_error("Failed to retrieve results: #{e.message}")
        end
      end

      # batch cancel [JOB_ID]
      def cmd_cancel(args)
        job_id = args[0]

        unless job_id
          print_error("Job ID is required")
          print_info("Usage: monadic-chat batch cancel <JOB_ID>")
          return
        end

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        unless prompt_system.yes?("Cancel job #{job_id}?", default: false)
          print_info("Cancelled")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        begin
          job = processor.cancel(job_id)
          print_success("Job cancelled")
          puts "Status: #{format_status(job['status'])}"
        rescue StandardError => e
          print_error("Failed to cancel: #{e.message}")
        end
      end

      # batch delete [JOB_ID]
      def cmd_delete(args)
        job_id = args[0]

        unless job_id
          print_error("Job ID is required")
          print_info("Usage: monadic-chat batch delete <JOB_ID>")
          return
        end

        # Authenticate (not strictly needed but consistent)
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        unless prompt_system.yes?("Delete local job record #{job_id}?", default: false)
          print_info("Cancelled")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        if processor.delete_job(job_id)
          print_success("Job record deleted")
        else
          print_error("Job not found: #{job_id}")
        end
      end

      # batch wait [JOB_ID] [OPTIONS]
      def cmd_wait(args)
        job_id = args[0]

        unless job_id
          print_error("Job ID is required")
          print_info("Usage: monadic-chat batch wait <JOB_ID> [--interval SECONDS]")
          return
        end

        options = parse_options(args[1..])
        interval = options[:interval] || 30

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)

        print_info("Waiting for job completion (checking every #{interval}s, press Ctrl+C to stop)...")
        puts ""

        begin
          start_time = Time.now
          last_status = nil

          loop do
            job = processor.check_status(job_id)
            elapsed = (Time.now - start_time).to_i

            # Show progress update
            progress = "#{job.dig('stats', 'completed')}/#{job.dig('stats', 'total')}"
            status_line = "\r[#{format_elapsed(elapsed)}] Status: #{format_status(job['status'])} | Progress: #{progress}"
            print status_line.ljust(80)

            case job["status"]
            when "completed"
              puts ""
              print_success("Job completed!")
              puts ""
              puts "Get results: monadic-chat batch result #{job_id}"
              return
            when "failed", "expired", "cancelled"
              puts ""
              print_error("Job #{job['status']}")
              if job["errors"] && !job["errors"].empty?
                job["errors"].each do |error|
                  puts "  - #{error['message'] || error}"
                end
              end
              return
            end

            sleep interval
          end
        rescue Interrupt
          puts ""
          print_info("Stopped waiting. Job is still #{processor.check_status(job_id)['status']}")
        rescue StandardError => e
          puts ""
          print_error("Error: #{e.message}")
        end
      end

      # batch clean [OPTIONS]
      def cmd_clean(args)
        options = parse_options(args)

        # Authenticate
        openai_completion = MonadicChat.authenticate(message: false)
        unless openai_completion
          print_error("Authentication failed")
          return
        end

        processor = Batch::Processor.new(openai_completion.access_token)
        jobs = processor.list_jobs

        # Find jobs to clean
        cleanable_statuses = %w[failed expired cancelled]
        cleanable_jobs = jobs.select { |j| cleanable_statuses.include?(j["status"]) }

        if cleanable_jobs.empty?
          print_info("No jobs to clean (failed/expired/cancelled)")
          return
        end

        print_header("Jobs to Clean")
        cleanable_jobs.each do |job|
          puts "  #{job['job_id']} (#{job['status']})"
        end
        puts ""

        unless prompt_system.yes?("Delete #{cleanable_jobs.size} job records?", default: false)
          print_info("Cancelled")
          return
        end

        deleted = 0
        cleanable_jobs.each do |job|
          if processor.delete_job(job["job_id"])
            deleted += 1
          end
        end

        print_success("Deleted #{deleted} job records")
      end

      # batch profile [subcommand]
      def cmd_profile(args)
        subcommand = args[0]

        case subcommand
        when "list", "ls", nil
          profile_list
        when "show"
          profile_show(args[1])
        when "save", "add", "create"
          profile_save(args[1..])
        when "delete", "del", "rm"
          profile_delete(args[1])
        else
          print_error("Unknown profile command: #{subcommand}")
          profile_help
        end
      end

      def profile_list
        profiles = Batch::ProfileManager.list

        print_header("Batch Profiles")

        if profiles.empty?
          print_info("No profiles found")
          return
        end

        profiles.each do |name, config|
          puts pastel.bold(name)
          puts "  Model: #{config['model'] || 'default'}"
          puts "  Max tokens: #{config['max_tokens'] || 'default'}"
          puts "  System prompt: #{config['system_prompt'] ? truncate(config['system_prompt'], 50) : 'None'}"
          puts ""
        end
      end

      def profile_show(name)
        unless name
          print_error("Profile name is required")
          print_info("Usage: monadic-chat batch profile show <NAME>")
          return
        end

        profile = Batch::ProfileManager.get(name)

        unless profile
          print_error("Profile not found: #{name}")
          return
        end

        print_header("Profile: #{name}")
        puts "Model: #{profile['model'] || 'default'}"
        puts "Max tokens: #{profile['max_tokens'] || 'default'}"
        if profile['system_prompt']
          puts "System prompt:"
          puts "  #{profile['system_prompt']}"
        else
          puts "System prompt: None"
        end
      end

      def profile_save(args)
        name = args[0]

        unless name
          print_error("Profile name is required")
          print_info("Usage: monadic-chat batch profile save <NAME> [OPTIONS]")
          return
        end

        if name == "default"
          print_error("Cannot modify the default profile")
          return
        end

        options = parse_options(args[1..])

        if options.empty?
          print_error("At least one option is required")
          print_info("Options: --model, --max-tokens, --system")
          return
        end

        # Build config from options
        config = {}
        config["model"] = options[:model] if options[:model]
        config["max_tokens"] = options[:max_tokens] if options[:max_tokens]
        config["system_prompt"] = options[:system_prompt] if options[:system_prompt]

        # Validate model if specified
        if config["model"] && !config["model"].start_with?("gpt-5")
          print_error("Only GPT-5 series models are supported")
          return
        end

        existing = Batch::ProfileManager.exists?(name)
        Batch::ProfileManager.save(name, config)

        if existing
          print_success("Profile '#{name}' updated")
        else
          print_success("Profile '#{name}' created")
        end

        profile_show(name)
      end

      def profile_delete(name)
        unless name
          print_error("Profile name is required")
          print_info("Usage: monadic-chat batch profile delete <NAME>")
          return
        end

        if name == "default"
          print_error("Cannot delete the default profile")
          return
        end

        unless Batch::ProfileManager.exists?(name)
          print_error("Profile not found: #{name}")
          return
        end

        unless prompt_system.yes?("Delete profile '#{name}'?", default: false)
          print_info("Cancelled")
          return
        end

        Batch::ProfileManager.delete(name)
        print_success("Profile '#{name}' deleted")
      end

      def profile_help
        puts <<~HELP
          #{pastel.bold('Batch Profile Commands:')}

          #{pastel.bold('Usage:')}
            monadic-chat batch profile <command> [options]

          #{pastel.bold('Commands:')}
            list              List all profiles
            show <NAME>       Show profile details
            save <NAME>       Create or update a profile
            delete <NAME>     Delete a profile

          #{pastel.bold('Options for save:')}
            --model, -m       Model to use
            --max-tokens, -t  Max tokens
            --system, -s      System prompt

          #{pastel.bold('Examples:')}
            monadic-chat batch profile list
            monadic-chat batch profile save translator --model gpt-5 --system "Translate to Japanese"
            monadic-chat batch profile delete translator
        HELP
      end

      def cmd_help
        puts <<~HELP
          #{pastel.bold('Monadic Chat - Batch Processing')}

          #{pastel.bold('Usage:')}
            monadic-chat batch <command> [options]

          #{pastel.bold('Commands:')}
            start <INPUT>     Start a new batch job
            list, ls          List all batch jobs
            status <JOB_ID>   Check job status
            wait <JOB_ID>     Wait for job completion (polls until done)
            result <JOB_ID>   Retrieve job results
            cancel <JOB_ID>   Cancel a running job
            delete <JOB_ID>   Delete local job record
            clean             Remove all failed/expired/cancelled jobs
            profile           Manage saved profiles
            help              Show this help

          #{pastel.bold('Options for start:')}
            --profile, -p     Use saved profile
            --model, -m       Model to use (default: gpt-5-mini)
            --max-tokens, -t  Max tokens (default: 2000)
            --system, -s      System prompt

          #{pastel.bold('Options for list:')}
            --status          Filter by status (completed, failed, in_progress, etc.)

          #{pastel.bold('Options for wait:')}
            --interval, -i    Polling interval in seconds (default: 30)

          #{pastel.bold('Options for result:')}
            --output, -o      Output file path
            --format, -f      Output format: text, json, csv (default: text)

          #{pastel.bold('Examples:')}
            monadic-chat batch start ./documents/
            monadic-chat batch start input.txt --profile translator
            monadic-chat batch list
            monadic-chat batch wait batch_20241213120000_abc12345
            monadic-chat batch result batch_20241213120000_abc12345 --output ./results/
            monadic-chat batch clean
        HELP
      end

      # Helper methods
      def parse_options(args)
        options = {}
        args ||= []

        i = 0
        while i < args.length
          case args[i]
          when "--profile", "-p"
            options[:profile] = args[i + 1]
            i += 2
          when "--model", "-m"
            options[:model] = args[i + 1]
            i += 2
          when "--max-tokens", "-t"
            options[:max_tokens] = args[i + 1].to_i
            i += 2
          when "--system", "-s"
            options[:system_prompt] = args[i + 1]
            i += 2
          when "--status"
            options[:status] = args[i + 1]
            i += 2
          when "--output", "-o"
            options[:output] = args[i + 1]
            i += 2
          when "--format", "-f"
            options[:format] = args[i + 1]
            i += 2
          when "--interval", "-i"
            options[:interval] = args[i + 1].to_i
            i += 2
          else
            i += 1
          end
        end

        options
      end

      def build_config(options)
        # Start with profile defaults (or system defaults)
        profile_name = options[:profile]
        base_config = Batch::ProfileManager.get_merged(profile_name)

        # Command-line options override profile settings
        {
          model: options[:model] || base_config["model"] || "gpt-5-mini",
          max_tokens: options[:max_tokens] || base_config["max_tokens"] || 2000,
          system_prompt: options[:system_prompt] || base_config["system_prompt"]
        }
      end

      def estimate_cost(record_count, model)
        # Very rough estimate based on typical token usage
        # Batch API provides 50% discount
        avg_input_tokens = 500
        avg_output_tokens = 200

        cost_per_1k_input = case model
                           when /gpt-5\.2/ then 0.015
                           when /gpt-5\.1/ then 0.010
                           when /gpt-5-mini/ then 0.003
                           when /gpt-5/ then 0.005
                           else 0.005
                           end

        cost_per_1k_output = cost_per_1k_input * 3 # Typically 3x input cost

        total_input_cost = (record_count * avg_input_tokens / 1000.0) * cost_per_1k_input
        total_output_cost = (record_count * avg_output_tokens / 1000.0) * cost_per_1k_output

        (total_input_cost + total_output_cost) * 0.5 # 50% Batch API discount
      end

      def save_results(results, output_path, format, job)
        case format
        when "json"
          output_file = output_path.end_with?(".json") ? output_path : "#{output_path}/results.json"
          FileUtils.mkdir_p(File.dirname(output_file))
          File.write(output_file, JSON.pretty_generate({
            job_id: job['job_id'],
            created_at: job['created_at'],
            results: results.map { |r| { id: r[:custom_id], source: r[:source], text: r[:text], error: r[:error] } }
          }))
          print_success("Results saved to: #{output_file}")

        when "csv"
          require "csv"
          output_file = output_path.end_with?(".csv") ? output_path : "#{output_path}/results.csv"
          FileUtils.mkdir_p(File.dirname(output_file))
          CSV.open(output_file, "w") do |csv|
            csv << ["id", "source", "text", "error"]
            results.each do |r|
              csv << [r[:custom_id], r[:source], r[:text], r[:error]&.to_s]
            end
          end
          print_success("Results saved to: #{output_file}")

        else # text/folder
          FileUtils.mkdir_p(output_path)
          results.each do |result|
            filename = result[:source] || "#{result[:custom_id]}.txt"
            # Sanitize filename
            filename = filename.gsub(/[^a-zA-Z0-9._-]/, "_")
            file_path = File.join(output_path, filename)

            if result[:error]
              File.write(file_path, "ERROR: #{result[:error]['message'] || result[:error]}")
            else
              File.write(file_path, result[:text])
            end
          end
          print_success("Results saved to: #{output_path}/ (#{results.size} files)")
        end
      end

      def format_status(status)
        case status
        when "completed"
          pastel.green(status)
        when "failed", "expired", "cancelled"
          pastel.red(status)
        when "in_progress", "finalizing"
          pastel.yellow(status)
        else
          status
        end
      end

      def format_time(iso_time)
        return "N/A" unless iso_time

        Time.parse(iso_time).localtime.strftime("%Y-%m-%d %H:%M")
      rescue
        iso_time
      end

      def format_elapsed(seconds)
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        secs = seconds % 60

        if hours > 0
          format("%02d:%02d:%02d", hours, minutes, secs)
        else
          format("%02d:%02d", minutes, secs)
        end
      end

      def truncate(str, max_length)
        return str if str.nil? || str.length <= max_length

        str[0, max_length - 3] + "..."
      end

      def print_header(text)
        puts ""
        puts pastel.bold("=== #{text} ===")
        puts ""
      end

      def print_error(message)
        puts pastel.red("Error: #{message}")
      end

      def print_success(message)
        puts pastel.green("✓ #{message}")
      end

      def print_info(message)
        puts pastel.cyan(message)
      end

      # Accessor for PASTEL constant
      def pastel
        MonadicChat::PASTEL
      end

      # Accessor for PROMPT_SYSTEM constant
      def prompt_system
        MonadicChat::PROMPT_SYSTEM
      end
    end
  end
end
