# frozen_string_literal: true

require "rspec/retry"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter integration tests unless INTEGRATION env var is set
  config.filter_run_excluding integration: true unless ENV["INTEGRATION"]

  # Output formatting
  config.formatter = :documentation if ENV["VERBOSE"]

  # Retry configuration for flaky integration tests
  # Integration tests depend on external API and may fail intermittently
  config.verbose_retry = true
  config.default_retry_count = 2
  config.exceptions_to_retry = [RSpec::Expectations::ExpectationNotMetError]

  # Only retry integration tests
  config.around(:each, :integration) do |example|
    example.run_with_retry retry: 2
  end
end
