# frozen_string_literal: true

require "monadic_chat"
MonadicChat.require_apps

COMPLETION = MonadicChat.authenticate(message: false)

NUM_RETRY = 3

# model_to_use = "gpt-3.5-turbo"
model_to_use = "gpt-4"

PARAMS = {
  "model" => model_to_use
}

availability = OpenAI.models(COMPLETION.access_token).any? do |model|
  model["id"] == model_to_use
end

if availability
  puts "#{model_to_use} is available to use"
else
  puts "#{model_to_use} is not available. Using #{fallback} instead."
  model_to_use = fallback
end
