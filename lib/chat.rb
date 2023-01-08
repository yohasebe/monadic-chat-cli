# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Chat < App
    DESC = "Natural Language Chat Agent"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion)
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.3,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.1,
        "frequency_penalty" => 0.1
      }
      super(params,
            TEMPLATES["chat"],
            {},
            "conversation",
            "response",
            proc do |res|
              res["conversation"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 2000
      @completion = openai_completion
    end
  end
end
