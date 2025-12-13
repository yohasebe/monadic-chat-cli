# frozen_string_literal: true

# Integration tests requiring OpenAI API authentication
# Run with: INTEGRATION=1 bundle exec rspec spec/normal_mode_chat_spec.rb

require_relative "./monadic_params"

RSpec.describe "Chat", :integration do
  chat = Chat.new(COMPLETION, research_mode: false, params: PARAMS)

  inputs = [
    "What is the best place to visit in Texas?",
    "What do people say about the place?",
    "How can I go there from Kansai, Japan?",
    "What are the latest news about Austin, Texas?",
    "What is the weather there today?"
  ]

  inputs.each do |input|
    chat.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  it "gives as many responses as the number of prompts given" do
    expect(chat.turns).to be inputs.size
  end
end
