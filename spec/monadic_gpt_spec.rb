# frozen_string_literal: true

require "json"

PARAMS = {
  model: "text-davinci-003",
  max_tokens: 300,
  temperature: 0.0,
  top_p: 1.0,
  stream: false,
  logprobs: nil,
  echo: false,
  stop: nil,
  presence_penalty: 0.0,
  frequency_penalty: 0.0
}.freeze

RSpec.describe MonadicGpt do
  it "has a version number" do
    expect(MonadicGpt::VERSION).not_to be nil
  end
end

RSpec.describe OpenAI do
  it "Retrieves models using OpenAI API" do
    models = OpenAI.models(ACCESS_TOKEN)
    expect(!models.empty?).to be true
  end

  context "an object specilizing 'completion' created" do
    completion = OpenAI::Completion.new(ACCESS_TOKEN)
    params = PARAMS.dup

    it "can return a text" do
      params[:prompt] = "What is the Japanese translation for 'Ruby'?"
      expect(completion.run(params).keys).to include "choices", "usage"
    end

    it "can return a json object" do
      params[:prompt] = <<~PROMPT
        What is the Japanese translation for Ruby? Give your response as a JSON object of the structure below\n
        ```json
        {"answer": ""}
        ```
      PROMPT

      res = completion.run_expecting_json(params)
      expect(res.keys).to include "answer"
    end

    it "can iterate multiple prompts" do
      prompts = [
        "what is the capital of Japan?",
        "what is the second largest city of Japan?",
        "what is the third largest city of Japan?"
      ]

      template = <<~TEMPLATE
        Set your response to the following prompt at the end of the value list of "responses" property of a JSON object in the structure shown blow. Then set the prompt at the end of the value list of the "prompts" property of the JSON object. \n
        Prompt: {{PROMPT}}\n
        ```json
        {
          "responses": [],
          "prompts": []
        }
        ```
      TEMPLATE

      replace_key = "{{PROMPT}}"

      num_prompts = prompts.size
      res = completion.run_iteration(params, prompts, template, replace_key)
      expect(res.keys).to include "responses", "prompts"
      expect(res["responses"].size).to be num_prompts
      expect(res["prompts"].size).to be num_prompts
    end
  end
end
