# frozen_string_literal: true

require_relative "../lib/monadic_chat"
MonadicChat.require_apps

COMPLETION = MonadicChat.authenticate(message: false)

PARAMS = {
  "model" => "gpt-3.5-turbo"
}

SETTINGS = {
  "num_retrials" => 3
}

availability = OpenAI.models(COMPLETION.access_token).any? do |model|
  model["id"] == PARAMS["model"]
end

puts "#{PARAMS["model"]} is available to use" if availability
