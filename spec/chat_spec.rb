# frozen_string_literal: true

require "json"

config = JSON.parse(File.read(File.join(Dir.home, "monadic_gpt.conf")))
ACCESS_TOKEN = config["access_token"]

RSpec.describe MonadicGpt::Chat do
  it "creates a chat object" do
    chat = MonadicGpt::Chat.new
    expect(chat).to be_truthy
  end
end
