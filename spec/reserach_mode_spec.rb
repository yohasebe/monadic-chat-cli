# frozen_string_literal: true

num_retry = 3

# model_to_use = "gpt-4"
# model_to_use = "gpt-3.5-turbo"
model_to_use = "text-davinci-003"

params = {
  "model" => model_to_use,
  "max_tokens" => 1000
}

RSpec.describe "Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = Translate.new(COMPLETION, replacements: replacements, research_mode: true, stream: true, params: params)
  translate.fulfill_placeholders
  turns_initial = translate.objectify["turns"].to_i

  input1 = "面白く読みやすい(readable)文章を書くことはとても難しい。"
  translate.bind(input1, num_retry: num_retry)
  input2 = "それでも鍛錬(practice)を続けるよりほかはない。"
  translate.bind(input2, num_retry: num_retry)
  input3 = "いつか熟練した(proficient)書き手になる日を夢見て。"
  translate.bind(input3, num_retry: num_retry)
  input4 = "読みやすく、面白い文章をたくさん読んで勉強するんだ。"
  translate.bind(input4, num_retry: num_retry)
  input5 = "具体的には(specifically)何を読んだらいいだろう？"
  translate.bind(input5, num_retry: num_retry)
  input6 = "何人かの知人(acquaintance)に聞いてみた。"
  translate.bind(input6, num_retry: num_retry)
  input7 = "ある人は村上春樹の短編(short story)が良いと言う"
  translate.bind(input7, num_retry: num_retry)
  input8 = "別の人は彼の小説よりもエッセイが良いと言う。"
  translate.bind(input8, num_retry: num_retry)
  input9 = "どちらも(both)読んでみよう。"
  translate.bind(input9, num_retry: num_retry)
  input10 = "後は自分が書いたものを他の人に読んでもらうことだ。"
  translate.bind(input10, num_retry: num_retry)
  input11 = "それが一番効果的(effective)かもしれないな。"
  translate.bind(input11, num_retry: num_retry)
  input12 = "とにかく続けることが大切(essential)だろうな。"
  translate.bind(input12, num_retry: num_retry)
  translate.show_data
  translate.show_template

  it "gives responses in json having certain properties" do
    expect(translate.objectify.keys).to include "mode", "turns", "prompt", "response", "target_lang"
  end

  it "gives as many responses as the number of prompts given" do
    expect(translate.objectify["turns"].to_i).to eq turns_initial + 12
  end
end

RSpec.describe "Chat" do
  chat = Chat.new(COMPLETION, research_mode: true, stream: true, params: params)
  turns_initial = chat.objectify["turns"].to_i

  input1 = "What is the best place to visit in Texas?"
  chat.bind(input1, num_retry: num_retry)
  input2 = "What do people say about the place?"
  chat.bind(input2, num_retry: num_retry)
  input3 = "How can I go there from Kansai, Japan?"
  chat.bind(input3, num_retry: num_retry)
  input4 = "By the way, are there any cities in Japan that have a sister city relationship with Texas cities?"
  chat.bind(input4, num_retry: num_retry)
  chat.show_data
  chat.show_template

  it "gives responses in json having certain properties" do
    expect(chat.objectify.keys).to include "mode", "turns", "response", "language", "topics"
  end

  it "gives as many responses as the number of prompts given" do
    expect(chat.objectify["turns"].to_i).to eq turns_initial + 4
  end
end

RSpec.describe "MonadicChat:Novel" do
  novel = Novel.new(COMPLETION, research_mode: true, stream: true, params: params)
  turns_initial = novel.objectify["turns"].to_i

  input1 = "Tom woke up to the sound of pouring rain."
  novel.bind(input1, num_retry: num_retry)
  input2 = "he decided to call his old friend first time in many years."
  novel.bind(input2, num_retry: num_retry)
  input3 = "the voice of the person the other end was an unfamilier one."
  novel.bind(input3, num_retry: num_retry)
  input4 = "it turned out that the person was my friend's son"
  novel.bind(input4, num_retry: num_retry)
  novel.show_data
  novel.show_template

  it "gives responses in json having certain properties" do
    expect(novel.objectify.keys).to include "mode", "turns", "response"
  end

  it "gives as many responses as the number of prompts given" do
    expect(novel.objectify["turns"].to_i).to eq turns_initial + 4
  end
end

RSpec.describe "Code" do
  code = Code.new(COMPLETION, research_mode: true, stream: true, params: params)
  turns_initial = code.objectify["turns"].to_i

  input1 = "Write a command line app that shows the current global IP in Ruby."
  code.bind(input1, num_retry: num_retry)
  input2 = "Make the code capable of showing the approximate geographical locatioin."
  code.bind(input2, num_retry: num_retry)
  input3 = "Add a usage example and a sample output to this code."
  code.bind(input3, num_retry: num_retry)
  input4 = "Write the same program using Python."
  code.bind(input4, num_retry: num_retry)
  code.show_data
  code.show_template

  it "gives responses in json having certain properties" do
    expect(code.objectify.keys).to include "mode", "turns", "prompt", "response"
  end

  it "gives as many responses as the number of prompts given" do
    expect(code.objectify["turns"].to_i).to eq turns_initial + 4
  end
end
