# frozen_string_literal: true

# JSON Schemas for Research Mode Structured Output
# These schemas ensure the model returns valid, parseable JSON responses

module MonadicChat
  RESEARCH_SCHEMAS = {
    "chat" => {
      "name" => "chat_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["chat"] },
          "response" => { "type" => "string", "description" => "The assistant's response to the user" },
          "summary" => { "type" => "string", "description" => "Summary of the conversation so far (max 100 words)" },
          "language" => { "type" => "string", "description" => "Language of the response (e.g., English, Japanese)" },
          "topics" => {
            "type" => "array",
            "items" => { "type" => "string" },
            "description" => "List of topics discussed"
          },
          "confidence" => {
            "type" => "number",
            "minimum" => 0.0,
            "maximum" => 1.0,
            "description" => "Confidence in the response (0.0-1.0)"
          },
          "ambiguity" => {
            "type" => "number",
            "minimum" => 0.0,
            "maximum" => 1.0,
            "description" => "Ambiguity of the user input (0.0-1.0)"
          }
        },
        "required" => ["mode", "response", "summary", "language", "topics", "confidence", "ambiguity"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    "code" => {
      "name" => "code_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["chat"] },
          "response" => { "type" => "string", "description" => "The assistant's response with code" },
          "summary" => { "type" => "string", "description" => "Summary of the conversation so far (max 100 words)" },
          "language" => { "type" => "string", "description" => "Language of the response" },
          "topics" => {
            "type" => "array",
            "items" => { "type" => "string" },
            "description" => "List of programming topics discussed"
          }
        },
        "required" => ["mode", "response", "summary", "language", "topics"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    "novel" => {
      "name" => "novel_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["novel"] },
          "response" => { "type" => "string", "description" => "The next paragraph of the story (max 200 words)" },
          "summary" => { "type" => "string", "description" => "Summary of the story so far (max 100 words)" }
        },
        "required" => ["mode", "response", "summary"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    "translate" => {
      "name" => "translate_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["translate"] },
          "target_lang" => { "type" => "string", "description" => "Target language for translation" },
          "response" => { "type" => "string", "description" => "The translated text" },
          "dictionary" => {
            "type" => "object",
            "additionalProperties" => { "type" => "string" },
            "description" => "Dictionary of user-suggested translations"
          }
        },
        "required" => ["mode", "target_lang", "response", "dictionary"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    "wikipedia" => {
      "name" => "wikipedia_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["wikipedia"] },
          "response" => { "type" => "string", "description" => "Response based on Wikipedia search results" },
          "language" => { "type" => "string", "description" => "Language of the response" },
          "summary" => { "type" => "string", "description" => "Summary of the conversation (max 100 words)" },
          "topics" => {
            "type" => "array",
            "items" => { "type" => "string" },
            "description" => "List of topics discussed"
          }
        },
        "required" => ["mode", "response", "language", "summary", "topics"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    "linguistic" => {
      "name" => "linguistic_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "enum" => ["linguistic"] },
          "response" => { "type" => "string", "description" => "Linguistic analysis with tree structure" },
          "sentence_type" => {
            "type" => "array",
            "items" => {
              "type" => "string",
              "enum" => ["declarative", "interrogative", "imperative", "exclamatory"]
            },
            "description" => "Types of the sentence"
          },
          "sentiment" => {
            "type" => "array",
            "items" => { "type" => "string" },
            "description" => "Sentiment analysis results (e.g., happy, sad, excited)"
          },
          "summary" => { "type" => "string", "description" => "Summary with discourse markers (max 100 words)" },
          "relevance" => {
            "type" => "number",
            "minimum" => 0.0,
            "maximum" => 1.0,
            "description" => "Relevance to previous discussion (0.0-1.0)"
          }
        },
        "required" => ["mode", "response", "sentence_type", "sentiment", "summary", "relevance"],
        "additionalProperties" => false
      },
      "strict" => true
    },

    # Default/fallback schema for custom apps created from boilerplate
    "default" => {
      "name" => "default_response",
      "schema" => {
        "type" => "object",
        "properties" => {
          "mode" => { "type" => "string", "description" => "The app mode name" },
          "response" => { "type" => "string", "description" => "The assistant's response" },
          "summary" => { "type" => "string", "description" => "Summary of the conversation (max 100 words)" },
          "language" => { "type" => "string", "description" => "Language of the response" },
          "topics" => {
            "type" => "array",
            "items" => { "type" => "string" },
            "description" => "List of topics discussed"
          }
        },
        "required" => ["mode", "response", "summary", "language", "topics"],
        "additionalProperties" => false
      },
      "strict" => true
    }
  }.freeze

  # Get schema for a specific app (with fallback to default)
  def self.research_schema(app_name)
    RESEARCH_SCHEMAS[app_name] || RESEARCH_SCHEMAS["default"]
  end

  # Get schema for Responses API format
  def self.research_schema_for_responses_api(app_name)
    schema = research_schema(app_name)
    return nil unless schema

    {
      "format" => {
        "type" => "json_schema",
        "name" => schema["name"],
        "schema" => schema["schema"],
        "strict" => schema["strict"]
      }
    }
  end

  # Get schema for Chat Completions API format
  def self.research_schema_for_chat_completions_api(app_name)
    schema = research_schema(app_name)
    return nil unless schema

    {
      "type" => "json_schema",
      "json_schema" => {
        "name" => schema["name"],
        "schema" => schema["schema"],
        "strict" => schema["strict"]
      }
    }
  end
end
