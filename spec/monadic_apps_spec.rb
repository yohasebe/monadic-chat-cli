# frozen_string_literal: true

completion = OpenAI::Completion.new(ACCESS_TOKEN)
num_retry = 2

RSpec.describe "MonadicGpt::Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = MonadicGpt::Translate.new(completion, replacements)
  translate.fulfill_placeholders
  input1 = "吾輩は猫である。"
  translate.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "名前はまだない"
  res = translate.bind_and_unwrap(input2, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "original", "translation", "num_tokens", "context", "target_lang"
  end

  print TTY::Markdown.parse("***")
  print "MonadicGpt::Translation", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["context"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicGpt::Chat" do
  chat = MonadicGpt::Chat.new(completion)
  input1 = "What is the best place to visit in Texas?"
  chat.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  res = chat.bind_and_unwrap(input2, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "response", "conversation", "num_tokens", "language", "topics"
  end

  print TTY::Markdown.parse("***")
  print "MonadicGpt::Chat", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicGpt::Novel" do
  novel = MonadicGpt::Novel.new(completion)
  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "He decided to call his old friend first time in many years."
  res = novel.bind_and_unwrap(input2, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "paragraph", "novel", "event", "num_tokens"
  end

  print TTY::Markdown.parse("***")
  print "MonadicGpt::Novel", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["novel"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end

RSpec.describe "MonadicGpt::Code" do
  code = MonadicGpt::Code.new(completion)
  input1 = "Write a command line app that shows the current global IP in Ruby"
  code.bind_and_unwrap(input1, num_retry: num_retry)
  input2 = "Add a usage example and a sample output to this code."
  res = code.bind_and_unwrap(input2, num_retry: num_retry)

  it "gives responses in json having certain properties" do
    expect(res.keys).to include "prompt", "response", "num_tokens", "conversation"
  end

  print TTY::Markdown.parse("***")
  print "MonadicGpt::Code", "\n"
  print TTY::Markdown.parse("***")
  print TTY::Markdown.parse(res["conversation"].map { |r| "- #{r}" }.join("\n"), indent: 0).strip, "\n"
  print TTY::Markdown.parse("***")
end
