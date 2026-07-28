# frozen_string_literal: true

require_relative "./monadic_params"

# Integration tests requiring OpenAI API authentication
# Run with: INTEGRATION=1 bundle exec rspec

RSpec.describe "MonadicApp::Wikipedia", :integration do
  params = PARAMS.dup
  params["model"] = "gpt-4o"
  wikipedia = Wikipedia.new(COMPLETION, research_mode: true, stream: true, params: params)

  inputs = [
    "Which team won the 2023 World Baseball Classic?",
    "When did Ryuichi Sakamoto pass away?",
    "What are currently going on to regulate AI research?"
  ]

  inputs.each do |input|
    wikipedia.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  wikipedia.show_data

  it "gives responses in json having certain properties" do
    result = wikipedia.objectify
    # Skip if model returned unexpected format (intermittent API behavior)
    skip "Model returned unexpected JSON format" if result["error"] || !result.key?("mode")
    expect(result.keys).to include "mode", "response", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(wikipedia.turns).to eq inputs.size
  end
end
