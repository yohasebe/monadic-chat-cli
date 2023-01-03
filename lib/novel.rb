# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Novel < App
    attr_accessor :template, :config, :params

    def initialize
      @num_tokens_kept = 1000
      super(File.read(TEMPLATES["novel"]),
            "novel",
            "text",
            proc do |res|
              if res["num_tokens"].to_i > @num_tokens_kept
                conv = res["plot"].split(/\n\n+/).map(&:strip)
                conv.shift(2)
                res["plot"] = conv.join("\n\n")
              end
              res
            end
           )
    end
  end
end
