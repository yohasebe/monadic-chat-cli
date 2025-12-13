# frozen_string_literal: true

require_relative "./monadic_params"

# Integration tests requiring OpenAI API authentication
# Run with: INTEGRATION=1 bundle exec rspec

RSpec.describe "MonadicApp::Wikipedia", :integration do
  wikipedia = Wikipedia.new(COMPLETION, research_mode: false, params: PARAMS)

  inputs = [
    "Which team won 2023 World Baseball Classic?",
    "Any famous people died in March, 2023?",
    "What are currently goingon to regulate AI research?"
  ]

  inputs.each do |input|
    wikipedia.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  it "gives as many responses as the number of prompts given" do
    expect(wikipedia.turns).to be inputs.size
  end
end
