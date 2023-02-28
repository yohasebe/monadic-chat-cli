# frozen_string_literal: true

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

RSpec.describe MonadicChat do
  it "has a version number" do
    expect(MonadicChat::VERSION).not_to be nil
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
        ```\n
        Wrap the json object with "<JSON>\n" and "\n</JSON>"
      PROMPT

      res = completion.run_expecting_json(params, num_retry: 1)
      expect(res.keys).to include "answer"
    end

    it "can iterate multiple prompts" do
      prompts = [
        "what is the largest city of Japan?",
        "what is the second largest city of Japan?",
        "what is the third largest city of Japan?"
      ]

      template = <<~TEMPLATE
        Set the following prompt at the end of the list of the "prompts" property of the JSON object.
        Then respond to the prompt and set your answer at the end of the "responses" list of the JSON object\n
        Prompt: {{PROMPT}}\n
        ```json
        {
          "prompts": ["what is the capital of Japan?"],
          "responses": ["Tokyo"]
        }
        ```\n
        Wrap the json object with "<JSON>\n" and "\n</JSON>"
      TEMPLATE

      replace_key = "{{PROMPT}}"

      num_prompts = prompts.size + 1
      res = completion.run_iteration(params, prompts, template, replace_key)
      expect(res.keys).to include "responses", "prompts"
      expect(res["responses"].size).to be num_prompts
      expect(res["prompts"].size).to be num_prompts
    end
  end
end