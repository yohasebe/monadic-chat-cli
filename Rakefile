# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

# Default spec task runs unit tests only (no API authentication required)
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/unit/**/*_spec.rb"
end

# Unit tests only
RSpec::Core::RakeTask.new("spec:unit") do |t|
  t.pattern = "spec/unit/**/*_spec.rb"
end

# Integration tests (requires API authentication)
RSpec::Core::RakeTask.new("spec:integration") do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rspec_opts = "--tag integration"
end

# All tests (unit + integration)
RSpec::Core::RakeTask.new("spec:all") do |t|
  t.pattern = "spec/**/*_spec.rb"
  ENV["INTEGRATION"] = "1"
end

# Optional: RuboCop if available
begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
  task default: %i[spec rubocop]
rescue LoadError
  task default: :spec
end

desc "Run unit tests (default)"
task test: :spec

desc "Run all tests including integration tests (requires API key)"
task "test:all" => "spec:all"
