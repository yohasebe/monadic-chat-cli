# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "MonadicApp::Wikipedia" do
  params = PARAMS.dup
  params["model"] = "gpt-3.5-turbo-0613"
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
    expect(wikipedia.objectify.keys).to include "mode", "response", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(wikipedia.turns).to eq inputs.size
  end
end
