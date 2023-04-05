# frozen_string_literal: true

RSpec.describe "MonadicApp::Code" do
  code = Code.new(COMPLETION, research_mode: true, stream: true, params: PARAMS)

  inputs = [
    "Write a command line app that shows the current global IP in Ruby.",
    "Make the code capable of showing the approximate geographical locatioin.",
    "Add a usage example and a sample output to this code.",
    "Write the same program using Python."
  ]

  inputs.each do |input|
    code.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  code.show_data

  it "gives responses in json having certain properties" do
    expect(code.objectify.keys).to include "mode", "response"
  end

  it "gives as many responses as the number of prompts given" do
    expect(code.turns).to eq inputs.size
  end
end
