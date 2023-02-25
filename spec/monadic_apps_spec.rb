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
  translate.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "名前はまだないんですよ。"
  translate.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "誰か良い名前を付けてくれませんかね。"
  res = translate.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "mode", "num_turns", "original", "translation", "num_tokens", "translation_history", "current_target_lang"
  end

  it "gives as many responses as the number of prompts given" do
    expect(res["translation_history"].size).to be res["num_turns"]
  end

  print TTY::Markdown.parse("***")
  print "MonadicChat::Translation", "\n"
  print "Num Turns: #{res["num_turns"]}", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["translation_history"].map { |r| "- #{r.join(" / ")}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicChat::Chat" do
  chat = MonadicChat::Chat.new(completion)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  res = chat.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "mode", "num_turns", "response", "conversation_history", "num_tokens", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(res["conversation_history"].size).to be res["num_turns"]
  end

  print TTY::Markdown.parse("***")
  print "MonadicChat::Chat", "\n"
  print "Num Turns: #{res["num_turns"]}", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["conversation_history"].map { |r| "- #{r.join(" / ")}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicChat:Novel" do
  novel = MonadicChat::Novel.new(completion)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "He decided to call his old friend first time in many years."
  novel.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "The voice of the person who spoke back from the other end was an unfamilier one."
  res = novel.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "mode", "num_turns", "new_paragraph", "paragraphs", "event", "num_tokens"
  end

  it "gives as many responses as the number of prompts given" do
    expect(res["paragraphs"].size).to be res["num_turns"]
  end

  print TTY::Markdown.parse("***")
  print "MonadicChat::Novel", "\n"
  print "Num Turns: #{res["num_turns"]}", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["paragraphs"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicChat::Code" do
  code = MonadicChat::Code.new(completion)
  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.bind_and_unwrap(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  res = code.bind_and_unwrap(input3, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "mode", "num_turns", "prompt", "response", "num_tokens", "conversation_history"
  end

  it "gives as many responses as the number of prompts given" do
    expect(res["conversation_history"].size).to be res["num_turns"]
  end

  print TTY::Markdown.parse("***")
  print "MonadicChat::Code", "\n"
  print "Num Turns: #{res["num_turns"]}", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["conversation_history"].map { |r| "- #{r.join(" / ")}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end
