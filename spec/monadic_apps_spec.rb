# frozen_string_literal: true

require "json"
require "tty-markdown"

completion = OpenAI::Completion.new(ACCESS_TOKEN)

RSpec.describe "MonadicGpt::Chat" do
  chat = MonadicGpt::Chat.new(completion)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_and_unwrap(input1)
  input2 = "What do people say about the place?"
  res = chat.bind_and_unwrap(input2)

  it "gives responses in json" do
    expect(res.keys).to include "response", "conversation", "num_tokens", "language", "topics"
  end

  it "'conversation' property contain a certain number of items" do
    expect(res["conversation"].size).to eq 8
  end

  print "--------------------", "\n"
  print "MonadicGPT::Chat", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end

RSpec.describe "MonadicGpt::Novel" do
  novel = MonadicGpt::Novel.new(completion)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_and_unwrap(input1)
  input2 = "He decided to call his old friend first time in many years."
  res = novel.bind_and_unwrap(input2)

  it "gives responses in json" do
    expect(res.keys).to include "text", "novel", "event", "num_tokens"
  end

  it "'novel' property contain a certain number of paragraphs" do
    expect(res["novel"].size).to be >= 2
  end

  print "--------------------", "\n"
  print "MonadicGPT::Novel", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["novel"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end

RSpec.describe "MonadicGpt::Code" do
  code = MonadicGpt::Code.new(completion)
  input1 = "Write a command line app that shows the current global IP in Ruby"
  code.bind_and_unwrap(input1)
  input2 = "Add the code with a usage example and a sample output."
  res = code.bind_and_unwrap(input2)

  it "gives responses in json" do
    expect(res.keys).to include "prompt", "response", "num_tokens", "conversation"
  end

  it "the 'response' value contains program code" do
    expect(res["response"]).to include "```", "ruby"
  end

  it "'conversation' property contain a certain number of items" do
    expect(res["conversation"].size).to be >= 6
  end

  print "--------------------", "\n"
  print "MonadicGPT::Code", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end

RSpec.describe "MonadicGpt::Translate" do
  code = MonadicGpt::Translate.new(completion)
  input1 = "吾輩は猫である。名前はまだ無い。どこで生れたかとんと見当けんとうがつかぬ。何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。"
  code.bind_and_unwrap(input1)
  input2 = "English"
  res = code.bind_and_unwrap(input2)

  it "gives responses in json" do
    expect(res.keys).to include "original", "translation", "num_tokens", "conversation", "target_lang"
  end

  it "'conversation' property contain a certain number of items" do
    expect(res["conversation"].size).to be >= 4
  end

  print "--------------------", "\n"
  print "MonadicGPT::Translation", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end
