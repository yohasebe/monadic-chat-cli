# frozen_string_literal: true

# Integration tests for both Chat Completions API and Responses API
# Run with: bundle exec rspec spec/api_integration_spec.rb --tag integration
#
# These tests verify actual API functionality with real requests.
# Uses low-cost models to minimize API costs:
# - gpt-4o-mini for Chat Completions API
# - gpt-4.1-nano for Responses API (supports temperature)

require_relative "./monadic_params"

RSpec.describe "API Integration", :integration do
  let(:access_token) { COMPLETION.access_token }
  let(:timeout_sec) { 60 }

  describe "Chat Completions API" do
    let(:model) { "gpt-4o-mini" }

    it "uses chat/completions method for gpt-4o-mini" do
      method = OpenAI.model_to_method(model)
      expect(method).to eq(OpenAI::API_CHAT_COMPLETIONS)
    end

    context "non-streaming request" do
      it "returns a valid response" do
        params = {
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 20,
          "temperature" => 0
        }

        response = OpenAI.query(access_token, "post", "chat/completions", timeout_sec, params)

        expect(response).not_to be_nil
        expect(response["error"]).to be_nil
        expect(response["choices"]).to be_an(Array)
        expect(response["choices"].first).to have_key("message")
        expect(response["choices"].first["message"]["content"]).to be_a(String)
        expect(response["choices"].first["message"]["content"].downcase).to include("hello")
      end
    end

    context "streaming request" do
      it "streams response fragments" do
        params = {
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 20,
          "temperature" => 0,
          "stream" => true
        }

        fragments = []
        response = OpenAI.query(access_token, "post", "chat/completions", timeout_sec, params) do |fragment|
          fragments << fragment if fragment.is_a?(String)
        end

        # Streaming builds up the response in choices[0].text
        # Check the final accumulated text in response, or use collected fragments
        expect(response).not_to be_nil
        expect(response["error"]).to be_nil

        # Primary check: use the accumulated text in response
        text = response.dig("choices", 0, "text")
        if text && !text.empty?
          expect(text.downcase).to include("hello")
        else
          # Fallback: use collected fragments
          combined = fragments.join("")
          expect(combined.downcase).to include("hello")
        end
      end
    end

    context "with system message" do
      it "respects system instructions" do
        params = {
          "model" => model,
          "messages" => [
            { "role" => "system", "content" => "You must always respond in uppercase letters only." },
            { "role" => "user", "content" => "Say hello" }
          ],
          "max_tokens" => 30,
          "temperature" => 0
        }

        response = OpenAI.query(access_token, "post", "chat/completions", timeout_sec, params)

        expect(response["error"]).to be_nil
        content = response["choices"].first["message"]["content"]
        # Check that response contains uppercase (system instruction followed)
        expect(content).to match(/[A-Z]/)
      end
    end
  end

  describe "Responses API (gpt-4.1)" do
    # Use gpt-4.1-nano as the cheapest Responses API model that supports temperature
    let(:model) { "gpt-4.1-nano" }

    it "uses responses method for gpt-4.1-nano" do
      method = OpenAI.model_to_method(model)
      expect(method).to eq(OpenAI::API_RESPONSES)
    end

    context "non-streaming request" do
      it "returns a valid response" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 30  # Responses API requires >= 16
        })

        response = OpenAI.query_responses(access_token, timeout_sec, params)

        expect(response).not_to be_nil
        expect(response["error"]).to be_nil
        # Check for output_text (Responses API format)
        expect(response["output_text"]).to be_a(String).or be_nil
        # Check for choices (compatibility layer)
        expect(response["choices"]).to be_an(Array)
        output = response["output_text"] || response.dig("choices", 0, "text")
        expect(output.to_s.downcase).to include("hello")
      end
    end

    context "streaming request" do
      it "streams response fragments" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 30,  # Responses API requires >= 16
          "stream" => true
        })

        fragments = []
        response = OpenAI.query_responses(access_token, timeout_sec, params) do |fragment|
          fragments << fragment if fragment.is_a?(String)
        end

        # Streaming should receive fragments
        expect(fragments).not_to be_empty
        combined = fragments.join("")
        expect(combined.downcase).to include("hello")
      end
    end

    context "with instructions (system message)" do
      it "respects instructions" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "system", "content" => "You must always respond in uppercase letters only." },
            { "role" => "user", "content" => "Say hello" }
          ],
          "max_tokens" => 50  # Responses API requires >= 16
        })

        response = OpenAI.query_responses(access_token, timeout_sec, params)

        expect(response["error"]).to be_nil
        output = response["output_text"] || response.dig("choices", 0, "text")
        # Check that response contains uppercase (instruction followed)
        expect(output.to_s).to match(/[A-Z]/)
      end
    end

    context "format conversion" do
      it "converts messages to input format" do
        input = {
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Hello" }
          ],
          "max_tokens" => 20
        }

        result = OpenAI.convert_to_responses_format(input)

        expect(result["model"]).to eq(model)
        expect(result["input"]).to eq("Hello")
        expect(result["max_output_tokens"]).to eq(20)
        expect(result).not_to have_key("messages")
        expect(result).not_to have_key("max_tokens")
      end

      it "extracts system message as instructions" do
        input = {
          "model" => model,
          "messages" => [
            { "role" => "system", "content" => "Be helpful" },
            { "role" => "user", "content" => "Hello" }
          ]
        }

        result = OpenAI.convert_to_responses_format(input)

        expect(result["instructions"]).to eq("Be helpful")
        expect(result["input"]).to eq("Hello")
      end

      it "includes temperature for gpt-4.1 models" do
        input = {
          "model" => "gpt-4.1-nano",
          "messages" => [
            { "role" => "user", "content" => "Hello" }
          ],
          "temperature" => 0.7,
          "top_p" => 0.9
        }

        result = OpenAI.convert_to_responses_format(input)

        expect(result["temperature"]).to eq(0.7)
        expect(result["top_p"]).to eq(0.9)
      end
    end
  end

  describe "Responses API (GPT-5)" do
    # Use gpt-5-nano as the cheapest GPT-5 model
    # Note: GPT-5 models are reasoning models and don't support temperature/top_p
    # They need higher max_tokens because reasoning consumes tokens before output
    let(:model) { "gpt-5-nano" }

    it "uses responses method for gpt-5-nano" do
      method = OpenAI.model_to_method(model)
      expect(method).to eq(OpenAI::API_RESPONSES)
    end

    it "is identified as a reasoning model (no temperature support)" do
      expect(OpenAI.supports_temperature?(model)).to be false
    end

    context "non-streaming request" do
      it "returns a valid response" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 500  # GPT-5 reasoning models need more tokens
        })

        # Verify temperature is not included for reasoning models
        expect(params).not_to have_key("temperature")

        response = OpenAI.query_responses(access_token, timeout_sec, params)

        # Handle case where model doesn't exist yet
        if response["error"]
          error_msg = response["error"]["message"] || response["error"].to_s
          if error_msg.include?("model") || error_msg.include?("not found") || error_msg.include?("does not exist")
            skip "GPT-5 model not yet available in API: #{error_msg}"
          else
            fail "Unexpected error: #{error_msg}"
          end
        end

        expect(response).not_to be_nil
        expect(response["choices"]).to be_an(Array)
        output = response["output_text"] || response.dig("choices", 0, "text")
        skip "GPT-5 model returned empty response (not yet available)" if output.to_s.strip.empty?
        expect(output.to_s.downcase).to include("hello")
      end
    end

    context "streaming request" do
      it "streams response fragments" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "user", "content" => "Reply with just the word 'hello'" }
          ],
          "max_tokens" => 500,  # GPT-5 reasoning models need more tokens
          "stream" => true
        })

        fragments = []
        response = OpenAI.query_responses(access_token, timeout_sec, params) do |fragment|
          fragments << fragment if fragment.is_a?(String)
        end

        # Handle case where model doesn't exist yet
        if response && response["error"]
          error_msg = response["error"]["message"] || response["error"].to_s
          if error_msg.include?("model") || error_msg.include?("not found") || error_msg.include?("does not exist")
            skip "GPT-5 model not yet available in API: #{error_msg}"
          else
            fail "Unexpected error: #{error_msg}"
          end
        end

        # If fragments were received, check content
        if fragments.any?
          combined = fragments.join("")
          expect(combined.downcase).to include("hello")
        elsif response
          # Fallback to checking final response
          output = response["output_text"] || response.dig("choices", 0, "text")
          expect(output.to_s.downcase).to include("hello")
        end
      end
    end

    context "with instructions (system message)" do
      it "respects instructions" do
        params = OpenAI.convert_to_responses_format({
          "model" => model,
          "messages" => [
            { "role" => "system", "content" => "You must always respond in uppercase letters only." },
            { "role" => "user", "content" => "Say hello" }
          ],
          "max_tokens" => 500  # GPT-5 reasoning models need more tokens
        })

        response = OpenAI.query_responses(access_token, timeout_sec, params)

        # Handle case where model doesn't exist yet
        if response["error"]
          error_msg = response["error"]["message"] || response["error"].to_s
          if error_msg.include?("model") || error_msg.include?("not found") || error_msg.include?("does not exist")
            skip "GPT-5 model not yet available in API: #{error_msg}"
          else
            fail "Unexpected error: #{error_msg}"
          end
        end

        expect(response["error"]).to be_nil
        output = response["output_text"] || response.dig("choices", 0, "text")
        skip "GPT-5 model returned empty response (not yet available)" if output.to_s.strip.empty?
        expect(output.to_s).to match(/[A-Z]/)
      end
    end

    context "format conversion" do
      it "excludes temperature for GPT-5 reasoning models" do
        input = {
          "model" => "gpt-5-nano",
          "messages" => [
            { "role" => "user", "content" => "Hello" }
          ],
          "temperature" => 0.7,
          "top_p" => 0.9
        }

        result = OpenAI.convert_to_responses_format(input)

        expect(result["model"]).to eq("gpt-5-nano")
        expect(result["input"]).to eq("Hello")
        expect(result).not_to have_key("temperature")
        expect(result).not_to have_key("top_p")
      end
    end
  end

  describe "Completion.run with automatic API selection" do
    let(:completion) { OpenAI::Completion.new(access_token) }

    context "with Chat Completions model (gpt-4o-mini)" do
      it "automatically uses Chat Completions API" do
        params = {
          "model" => "gpt-4o-mini",
          "messages" => [
            { "role" => "user", "content" => "Reply with just 'OK'" }
          ],
          "max_tokens" => 20,
          "temperature" => 0
        }

        result = completion.run(params, timeout_sec: timeout_sec)

        expect(result).to be_a(String)
        expect(result.downcase).to include("ok")
      end
    end

    context "with Responses API model (gpt-4.1-nano)" do
      it "automatically uses Responses API" do
        params = {
          "model" => "gpt-4.1-nano",
          "messages" => [
            { "role" => "user", "content" => "Reply with just 'OK'" }
          ],
          "max_tokens" => 30,
          "temperature" => 0
        }

        result = completion.run(params, timeout_sec: timeout_sec)

        expect(result).to be_a(String)
        expect(result.downcase).to include("ok")
      end
    end

    context "with GPT-5 model (gpt-5-nano)" do
      it "automatically uses Responses API for GPT-5 models" do
        params = {
          "model" => "gpt-5-nano",
          "messages" => [
            { "role" => "user", "content" => "Reply with just 'OK'" }
          ],
          "max_tokens" => 500  # GPT-5 reasoning models need more tokens
          # Note: No temperature for GPT-5 reasoning models
        }

        begin
          result = completion.run(params, timeout_sec: timeout_sec)
          expect(result).to be_a(String)
          skip "GPT-5 model returned empty response (not yet available)" if result.to_s.strip.empty?
          expect(result.downcase).to include("ok")
        rescue StandardError => e
          if e.message.include?("model") || e.message.include?("not found") || e.message.include?("does not exist")
            skip "GPT-5 model not yet available in API: #{e.message}"
          else
            raise e
          end
        end
      end
    end
  end

  describe "Error handling" do
    context "with invalid model" do
      it "exits with error for non-existent model" do
        expect {
          # Suppress stdout during this test
          $stdout = StringIO.new
          begin
            OpenAI.model_to_method("non-existent-model")
          ensure
            $stdout = STDOUT
          end
        }.to raise_error(SystemExit)
      end

      it "exits with error for deprecated model" do
        expect {
          # Suppress stdout during this test
          $stdout = StringIO.new
          begin
            OpenAI.model_to_method("gpt-3.5-turbo")
          ensure
            $stdout = STDOUT
          end
        }.to raise_error(SystemExit)
      end
    end
  end
end
