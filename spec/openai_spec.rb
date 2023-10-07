# frozen_string_literal: true

require_relative "./monadic_params"

RSpec.describe MonadicChat do
  it "has a version number" do
    expect(MonadicChat::VERSION).not_to be nil
  end
end

RSpec.describe OpenAI do
  it "Retrieves models using OpenAI API" do
    models = OpenAI.models(COMPLETION.access_token)
    models[0...10].each do |m|
      print "#{m["id"]}: "
      puts Time.at(m["created"]).strftime("%Y-%m-%d %H:%M:%S")
    end
    expect(!models.empty?).to be true
  end
end
