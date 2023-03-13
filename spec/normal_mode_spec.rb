# frozen_string_literal: true

num_retry = 2

RSpec.describe "Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = Translate.new(COMPLETION, replacements: replacements, research_mode: false)
  translate.fulfill_placeholders
  input1 = "ワタシは猫なんですけどね(as you see)。"
  translate.bind_normal_mode(input1, num_retry: num_retry)
  input2 = "名前はまだ(yet)ないんですよ。"
  translate.bind_normal_mode(input2, num_retry: num_retry)
  input3 = "誰か良い(special)名前を付けてくれませんかね。"
  translate.bind_normal_mode(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(translate.objectify.reject { |m| m["role"] == "system" }.size).to be 3 * 2
  end
end

RSpec.describe "Chat" do
  chat = Chat.new(COMPLETION, research_mode: false)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_normal_mode(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.bind_normal_mode(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  chat.bind_normal_mode(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(chat.objectify.reject { |m| m["role"] == "system" }.size).to be 3 * 2
  end
end

RSpec.describe "Novel" do
  novel = Novel.new(COMPLETION, research_mode: false)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_normal_mode(input1, num_retry: num_retry)
  input2 = "He decided to call his old friend first time in many years."
  novel.bind_normal_mode(input2, num_retry: num_retry)
  input3 = "The voice of the person who spoke back from the other end was an unfamilier one."
  novel.bind_normal_mode(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(novel.objectify.reject { |m| m["role"] == "system" }.size).to be 4 * 2
  end
end

RSpec.describe "Code" do
  code = Code.new(COMPLETION, research_mode: false)
  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind_normal_mode(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.bind_normal_mode(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  code.bind_normal_mode(input3, num_retry: num_retry)

  it "gives as many responses as the number of prompts given" do
    expect(code.objectify.reject { |m| m["role"] == "system" }.size).to be 4 * 2
  end
end
