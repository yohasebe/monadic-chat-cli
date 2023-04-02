# frozen_string_literal: true

RSpec.describe "MonadicApp::Novel" do
  novel = Novel.new(COMPLETION, research_mode: true, stream: true, params: PARAMS)

  inputs = [
    "Tom woke up to the sound of pouring rain.",
    "He decided to call his old friend first time in many years.",
    "The voice of the person who spoke back from the other end was an unfamilier one.",
    "It turned out that the person was my friend's son."
  ]

  inputs.each do |input|
    novel.bind(input, num_retry: NUM_RETRY)
  end

  novel.show_data

  it "gives responses in json having certain properties" do
    expect(novel.objectify.keys).to include "mode", "response"
  end

  it "gives as many responses as the number of prompts given" do
    expect(novel.turns).to eq inputs.size
  end
end
