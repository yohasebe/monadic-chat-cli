# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "Novel" do
  novel = Novel.new(COMPLETION, research_mode: false, params: PARAMS)

  inputs = [
    "Tom woke up to the sound of pouring rain.",
    "He decided to call his old friend first time in many years.",
    "The voice of the person who spoke back from the other end was an unfamilier one."
  ]

  inputs.each do |input|
    novel.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  it "gives as many responses as the number of prompts given" do
    expect(novel.turns).to be inputs.size
  end
end
