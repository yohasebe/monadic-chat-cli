# frozen_string_literal: true

require_relative "lib/monadic_chat/version"

Gem::Specification.new do |spec|
  spec.name = "monadic-chat"
  spec.version = MonadicChat::VERSION
  spec.authors = ["yohasebe"]
  spec.email = ["yohasebe@gmail.com"]

  spec.summary = "Highly configurable CLI client app for OpenAI chat/text-completion API"
  spec.description = <<~DESC
    Monadic Chat is a command-line client application program that uses OpenAI's Text Completion API and Chat API to enable chat-style conversations with OpenAI's artificial intelligence system in a ChatGPT-like style.
  DESC
  spec.homepage = "https://github.com/yohasebe/monadic-chat"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.10"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yohasebe/monadic-chat"
  spec.metadata["changelog_uri"] = "https://github.com/yohasebe/monadic-chat/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = ["monadic-chat"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"

  spec.add_dependency "blingfire"
  spec.add_dependency "http"
  spec.add_dependency "kramdown"
  spec.add_dependency "launchy"
  spec.add_dependency "oj"
  spec.add_dependency "pastel"
  spec.add_dependency "rexml", ">= 3.3.6"
  spec.add_dependency "rouge"
  spec.add_dependency "tty-box"
  spec.add_dependency "tty-cursor"
  spec.add_dependency "tty-markdown"
  spec.add_dependency "tty-progressbar"
  spec.add_dependency "tty-prompt"
  spec.add_dependency "tty-screen"
  spec.add_dependency "tty-spinner"
end
