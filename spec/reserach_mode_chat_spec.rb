# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "MonadicApp::Chat" do
  chat = Chat.new(COMPLETION, research_mode: true, stream: true, params: PARAMS)

  inputs = [
    "What is the best place to visit in Texas?",
    "What do people say about the place?",
    "How can I go there from Kansai, Japan?",
    "Are there any cities in Japan that have a sister city relationship with Texas cities?",
    "Do you know if there was any interesting news in Texas yesterday?",
    "What is the weather in Austin, Texas yesterday?"
  ]

  inputs.each do |input|
    chat.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  chat.show_data

  it "gives responses in json having certain properties" do
    expect(chat.objectify.keys).to include "mode", "response", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(chat.turns).to eq inputs.size
  end
end
