# frozen_string_literal: true

RSpec.describe "Translate" do
  replacements = {
    "mode" => :replace,
    "{{TARGET_LANG}}" => "English"
  }

  translate = Translate.new(COMPLETION, replacements: replacements, research_mode: false, params: PARAMS)
  translate.fulfill_placeholders

  inputs = [
    "ワタシは猫なんですけどね(as you see)。",
    "名前はまだ(yet)ないんですよ。",
    "誰か良い(special)名前を付けてくれませんかね。",
    "薄暗いじめじめしたところでニャー(meow)と鳴いてたんだ。",
    "そのことは覚えてる(remember)。",
    "で、その時に人間(human)というものに出会った。",
    "それは書生(student)という人間だったそうだ。",
    "すごく残酷(cruel)な種類の人間らしくてね。",
    "ワタシらをときどき捕えて(hunt)煮て食べたりしてたんだって。",
    "まあ(well)、そのときはよくわかんなくてさ。",
    "とくに怖い(scary)気持ちもなかったんだけど。",
    "ただ、手(palm)の上で持ち上げられた時はなんか変な感じだったな。"
  ]

  inputs.each do |input|
    translate.bind(input, num_retrials: SETTINGS["num_retrials"])
  end

  it "gives as many responses as the number of prompts given" do
    expect(translate.turns).to be inputs.size
  end
end
