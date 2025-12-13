# frozen_string_literal: true

# Integration tests requiring OpenAI API authentication
# Run with: INTEGRATION=1 bundle exec rspec spec/openai_spec.rb

require_relative "./monadic_params"

RSpec.describe OpenAI, :integration do
  describe ".models" do
    it "retrieves models using OpenAI API" do
      models = OpenAI.models(COMPLETION.access_token)
      models[0...5].each do |m|
        print "#{m["id"]}: "
        puts Time.at(m["created"]).strftime("%Y-%m-%d %H:%M:%S")
      end
      expect(models).not_to be_empty
    end

    it "returns array of model hashes" do
      models = OpenAI.models(COMPLETION.access_token)
      expect(models).to be_an(Array)
      expect(models.first).to have_key("id")
      expect(models.first).to have_key("created")
    end
  end

  describe "Completion", :integration do
    it "initializes with access token" do
      completion = OpenAI::Completion.new(COMPLETION.access_token)
      expect(completion.access_token).not_to be_nil
    end

    it "can retrieve models through completion instance" do
      completion = OpenAI::Completion.new(COMPLETION.access_token)
      models = completion.models
      expect(models).not_to be_empty
    end
  end
end
