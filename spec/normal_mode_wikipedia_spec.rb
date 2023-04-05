# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "MonadicApp::Wikipedia" do
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
