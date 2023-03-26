# frozen_string_literal: true

num_retry = 3

# model_to_use = "gpt-4"
# model_to_use = "gpt-3.5-turbo"
model_to_use = "gpt-4"

params = {
  "model" => model_to_use
}

availability = OpenAI.models(COMPLETION.access_token).any? do |model|
  model["id"] == model_to_use
end

if availability
  puts "#{model_to_use} is available to use"
else
  puts "#{model_to_use} is not available. Using #{fallback} instead."
  model_to_use = fallback
end

RSpec.describe "Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = Translate.new(COMPLETION, replacements: replacements, research_mode: false, params: params)
  translate.fulfill_placeholders
  input1 = "ワタシは猫なんですけどね(as you see)。"
  translate.bind(input1, num_retry: num_retry)
  input2 = "名前はまだ(yet)ないんですよ。"
  translate.bind(input2, num_retry: num_retry)
  input3 = "誰か良い(special)名前を付けてくれませんかね。"
  translate.bind(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(translate.objectify.reject { |m| m["role"] == "system" }.size).to be 3 * 2
  end
end

RSpec.describe "Chat" do
  chat = Chat.new(COMPLETION, research_mode: false, params: params)
  input1 = "What is the best place to visit in Texas?"
  chat.bind(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.bind(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  chat.bind(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(chat.objectify.reject { |m| m["role"] == "system" }.size).to be (3 + 1) * 2
  end
end

RSpec.describe "Novel" do
  novel = Novel.new(COMPLETION, research_mode: false, params: params)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind(input1, num_retry: num_retry)
  input2 = "He decided to call his old friend first time in many years."
  novel.bind(input2, num_retry: num_retry)
  input3 = "The voice of the person who spoke back from the other end was an unfamilier one."
  novel.bind(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(novel.objectify.reject { |m| m["role"] == "system" }.size).to be 4 * 2
  end
end

RSpec.describe "Code" do
  code = Code.new(COMPLETION, research_mode: false, params: params)
  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.bind(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  code.bind(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(code.objectify.reject { |m| m["role"] == "system" }.size).to be 4 * 2
  end
end
