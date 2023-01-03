# frozen_string_literal: true

require_relative "monadic_gpt"

module MonadicGpt
  class Chat < App
    attr_accessor :template, :config, :params

    def initialize
      @num_tokens_kept = 1000
      super(File.read(TEMPLATES["chat"]),
            "conversation",
            "response",
            proc do |res|
              if !@started
                conv = res["conversation"].split("\n").map(&:strip)
                conv.shift(4)
                res["conversation"] = conv.join("\n")
              elsif res["num_tokens"].to_i > @num_tokens_kept
                conv = res["conversation"].split("\n").map(&:strip)
                conv.shift(2)
                res["conversation"] = conv.join("\n")
              end
              res
            end
           )
    end
  end
end
