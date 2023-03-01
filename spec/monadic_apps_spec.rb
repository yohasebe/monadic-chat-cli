# frozen_string_literal: true

completion = OpenAI::Completion.new(ACCESS_TOKEN)
num_retry = 2

RSpec.describe "MonadicChat::Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = MonadicChat::Translate.new(completion, replacements)
  translate.fulfill_placeholders
  input1 = "ワタシは猫なんですけどね。"
  translate.wait.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "名前はまだないんですよ。"
  translate.wait.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "誰か良い名前を付けてくれませんかね。"
  translate.wait.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(translate.wait.objectify.keys).to include "mode", "num_turns", "original", "translation", "translation_history", "current_target_lang"
  end

  it "gives as many responses as the number of prompts given" do
    expect(translate.wait.objectify["translation_history"].size).to be translate.wait.objectify["num_turns"]
  end
end

RSpec.describe "MonadicChat::Chat" do
  chat = MonadicChat::Chat.new(completion)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.wait.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  chat.wait.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(chat.wait.objectify.keys).to include "mode", "num_turns", "response", "conversation_history", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(chat.wait.objectify["conversation_history"].size).to be chat.wait.objectify["num_turns"]
  end
end

RSpec.describe "MonadicChat:Novel" do
  novel = MonadicChat::Novel.new(completion)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "He decided to call his old friend first time in many years."
  novel.wait.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "The voice of the person who spoke back from the other end was an unfamilier one."
  novel.wait.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(novel.wait.objectify.keys).to include "mode", "num_turns", "response", "conversation_history", "prompt"
  end

  it "gives as many responses as the number of prompts given" do
    expect(novel.wait.objectify["conversation_history"].size).to be novel.wait.objectify["num_turns"]
  end
end

RSpec.describe "MonadicChat::Code" do
  code = MonadicChat::Code.new(completion)
  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.wait.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  code.wait.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(code.wait.objectify.keys).to include "mode", "num_turns", "prompt", "response", "conversation_history"
  end

  it "gives as many responses as the number of prompts given" do
    expect(code.wait.objectify["conversation_history"].size).to be code.wait.objectify["num_turns"]
  end
end
