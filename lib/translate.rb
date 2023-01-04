# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Translate < App
    DESC = "Interactive Multilingual Translator"

    attr_accessor :template, :config, :params, :completion

    def initialize(openai_completion, replacements = nil)
      params = {
        "model" => "text-davinci-003",
        "max_tokens" => 2000,
        "temperature" => 0.1,
        "top_p" => 1.0,
        "stream" => false,
        "logprobs" => nil,
        "echo" => false,
        "stop" => nil,
        "presence_penalty" => 0.0,
        "frequency_penalty" => 0.0
      }
      replacements ||= {
        "mode" => :interactive,
        "{{ORIGINAL}}" => "Original text",
        "{{TARGET_LANG}}" => "Target language",
        "{{PROMPT}}" => "translate the original text"
      }
      super(params,
            TEMPLATES["translate"],
            replacements,
            "translations",
            "translation",
            proc do |res|
              res["directions"].shift(2) if res["num_tokens"].to_i > @num_tokens_kept
              res
            end
           )
      @num_tokens_kept = 1000
      @completion = openai_completion
    end
  end
end
