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
    expect(res.keys).to include "paragraph", "novel", "event", "num_tokens"
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
    expect(res["response"]).to include "```"
  end

  print "--------------------", "\n"
  print "MonadicGPT::Code", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end

RSpec.describe "MonadicGpt::Translate" do
  replacements = {
    "mode" => :replace,
    "{{ORIGINAL}}" => "吾輩は猫である。名前はまだ無い。",
    "{{TARGET_LANG}}" => "English",
    "{{PROMPT}}" => "Translate in to natural English"
  }
  translate = MonadicGpt::Translate.new(completion, replacements)
  translate.fulfill_placeholders
  input = "Use the world 'this' instead of 'I' in the translation."
  res = translate.bind_and_unwrap(input)

  it "gives responses in json" do
    expect(res.keys).to include "original", "translation", "num_tokens", "translations", "target_lang"
  end

  print "--------------------", "\n"
  print "MonadicGPT::Translation", "\n"
  print "--------------------", "\n"
  print TTY::Markdown.parse(res["translations"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print "--------------------", "\n"
end
