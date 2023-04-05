# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "MonadicApp::Wikipedia" do
  wikipedia = Wikipedia.new(COMPLETION, research_mode: true, stream: true, params: PARAMS)

  inputs = [
    "Which team won 2023 World Baseball Classic?",
    "When did Ryuichi Sakamoto pass away?",
    "What are currently going on to regulate AI research?"
  ]

  inputs.each do |input|
    wikipedia.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  wikipedia.show_data

  it "gives responses in json having certain properties" do
    expect(wikipedia.objectify.keys).to include "mode", "response", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(wikipedia.turns).to eq inputs.size
  end
end
