# frozen_string_literal: true

num_retry = 3

RSpec.describe "MonadicChat::Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = MonadicChat::Translate.new(COMPLETION, replacements: replacements, research_mode: true, stream: true)
  translate.fulfill_placeholders
  input1 = "ワタシは猫なんですけどね。"
  translate.wait.bind_research_mode(input1, num_retry: num_retry)
  input2 = "名前はまだないんですよ。"
  translate.wait.bind_research_mode(input2, num_retry: num_retry)
  input3 = "誰か良い名前を付けてくれませんかね。"
  translate.wait.bind_research_mode(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(translate.wait.objectify.keys).to include "mode", "turns", "prompt", "response", "messages", "target_lang"
  end

  it "gives as many responses as the number of prompts given" do
    expect(translate.wait.objectify["messages"].size).to eq translate.wait.objectify["turns"]
  end
end

RSpec.describe "MonadicChat::Chat" do
  chat = MonadicChat::Chat.new(COMPLETION, research_mode: true, stream: true)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_research_mode(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.wait.bind_research_mode(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  chat.wait.bind_research_mode(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(chat.wait.objectify.keys).to include "mode", "turns", "response", "messages", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(chat.wait.objectify["messages"].size).to eq chat.wait.objectify["turns"]
  end
end

RSpec.describe "MonadicChat:Novel" do
  novel = MonadicChat::Novel.new(COMPLETION, research_mode: true, stream: true)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_research_mode(input1, num_retry: num_retry)
  input2 = "he decided to call his old friend first time in many years."
  novel.wait.bind_research_mode(input2, num_retry: num_retry)
  input3 = "the voice of the person the other end was an unfamilier one."
  novel.wait.bind_research_mode(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(novel.wait.objectify.keys).to include "mode", "turns", "response", "messages", "prompt"
  end

  it "gives as many responses as the number of prompts given" do
    expect(novel.wait.objectify["messages"].size).to eq novel.wait.objectify["turns"]
  end
end

RSpec.describe "MonadicChat::Code" do
  code = MonadicChat::Code.new(COMPLETION, research_mode: true, stream: true)
  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind_research_mode(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.wait.bind_research_mode(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  code.wait.bind_research_mode(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(code.wait.objectify.keys).to include "mode", "turns", "prompt", "response", "messages"
  end

  it "gives as many responses as the number of prompts given" do
    expect(code.wait.objectify["messages"].size).to eq code.wait.objectify["turns"]
  end
end
