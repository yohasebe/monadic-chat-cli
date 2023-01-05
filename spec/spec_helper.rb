# frozen_string_literal: true

require "monadic_gpt"
require "chat"
require "novel"
require "code"
require "translate"
require "oj"
Oj.mimic_JSON

CONFIG_FILE = File.join(Dir.home, "monadic_gpt.conf")
CONFIG = JSON.parse(File.read(CONFIG_FILE))
ACCESS_TOKEN = CONFIG["access_token"]

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
