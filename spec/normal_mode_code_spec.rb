# frozen_string_literal: true

RSpec.describe "Code" do
  code = Code.new(COMPLETION, research_mode: false, params: PARAMS)

  inputs = [
    "Write a command line app that shows the current global IP in Ruby.",
    "Make the code capable of showing the approximate geographical locatioin.",
    "Add a usage example and a sample output to this code."
  ]

  inputs.each do |input|
    code.bind(input, num_retry: NUM_RETRY)
  end

  it "gives as many responses as the number of prompts given" do
    expect(code.turns).to be inputs.size
  end
end
