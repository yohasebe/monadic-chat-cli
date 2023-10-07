# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe "MonadicApp::Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = Translate.new(COMPLETION, replacements: replacements, research_mode: true, stream: true, params: PARAMS)
  translate.fulfill_placeholders

  inputs = [
    "面白く読みやすい(readable)文章を書くことはとても難しい。",
    "それでも鍛錬(practice)を続けるよりほかはない。",
    "いつか熟練した(proficient)書き手になる日を夢見て。",
    "読みやすく、面白い文章をたくさん読んで勉強するんだ。",
    "具体的には(specifically)何を読んだらいいだろう？",
    "何人かの知人(acquaintance)に聞いてみた。",
    "ある人は村上春樹の短編(short story)が良いと言う",
    "別の人は彼の小説よりもエッセイが良いと言う。",
    "両方(both)読んでみようかな。",
    "後は自分が書いたものを他の人に読んでもらうことだ。",
    "それが一番効果的(effective)かもしれないな。"
  ]

  inputs.each do |input|
    translate.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  translate.show_data

  it "gives responses in json having certain properties" do
    expect(translate.objectify.keys).to include "mode", "response", "target_lang", "dictionary"
  end

  it "gives as many responses as the number of prompts given" do
    expect(translate.turns).to eq inputs.size
  end
end
