# frozen_string_literal: true

require "yaml"
require "fileutils"

module MonadicChat
  module Batch
    # Manages batch processing profiles (saved configurations)
    class ProfileManager
      PROFILES_FILE = File.join(Dir.home, ".monadic_chat", "batch_profiles.yml")

      # Default profile configuration
      DEFAULT_PROFILE = {
        "model" => "gpt-5-mini",
        "max_tokens" => 2000
      }.freeze

      class << self
        # List all available profiles
        # @return [Hash] All profiles with their configurations
        def list
          load_profiles
        end

        # Get a specific profile
        # @param name [String] Profile name
        # @return [Hash, nil] Profile configuration or nil if not found
        def get(name)
          profiles = load_profiles
          profiles[name.to_s]
        end

        # Save a new profile or update existing
        # @param name [String] Profile name
        # @param config [Hash] Configuration options
        # @return [Hash] The saved profile
        def save(name, config)
          profiles = load_profiles

          # Normalize config keys to strings
          normalized = {}
          config.each do |key, value|
            normalized[key.to_s] = value if value
          end

          profiles[name.to_s] = normalized
          write_profiles(profiles)
          normalized
        end

        # Delete a profile
        # @param name [String] Profile name
        # @return [Boolean] True if deleted, false if not found
        def delete(name)
          profiles = load_profiles
          return false unless profiles.key?(name.to_s)
          return false if name.to_s == "default"  # Can't delete default

          profiles.delete(name.to_s)
          write_profiles(profiles)
          true
        end

        # Check if a profile exists
        # @param name [String] Profile name
        # @return [Boolean]
        def exists?(name)
          profiles = load_profiles
          profiles.key?(name.to_s)
        end

        # Get profile config merged with defaults
        # @param name [String] Profile name (nil for default)
        # @return [Hash] Merged configuration
        def get_merged(name = nil)
          name = "default" if name.nil? || name.empty?

          profile = get(name)
          return DEFAULT_PROFILE.dup unless profile

          DEFAULT_PROFILE.merge(profile)
        end

        # Initialize profiles file with default profile
        # @return [void]
        def init
          return if File.exist?(PROFILES_FILE)

          default_profiles = {
            "default" => DEFAULT_PROFILE.dup
          }
          write_profiles(default_profiles)
        end

        private

        def load_profiles
          init unless File.exist?(PROFILES_FILE)

          content = File.read(PROFILES_FILE)
          profiles = YAML.safe_load(content, permitted_classes: [Symbol]) || {}

          # Ensure default profile exists
          profiles["default"] ||= DEFAULT_PROFILE.dup
          profiles
        rescue Errno::ENOENT
          { "default" => DEFAULT_PROFILE.dup }
        rescue Psych::SyntaxError => e
          warn "Warning: Invalid YAML in profiles file: #{e.message}"
          { "default" => DEFAULT_PROFILE.dup }
        end

        def write_profiles(profiles)
          FileUtils.mkdir_p(File.dirname(PROFILES_FILE))
          File.write(PROFILES_FILE, profiles.to_yaml)
        end
      end
    end
  end
end
