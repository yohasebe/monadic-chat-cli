# frozen_string_literal: true

module MonadicChat
  # Tool definitions in JSON Schema format for OpenAI native tool use API
  module ToolDefinitions
    # Wikipedia search tool
    WIKIPEDIA_SEARCH = {
      "type" => "function",
      "function" => {
        "name" => "wikipedia_search",
        "description" => "Search Wikipedia for factual information about a topic. Use this when you need encyclopedic knowledge or historical facts.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "query" => {
              "type" => "string",
              "description" => "The search query to look up on Wikipedia (in English)"
            }
          },
          "required" => ["query"],
          "additionalProperties" => false
        }
      }
    }.freeze

    # Web search tool
    WEB_SEARCH = {
      "type" => "function",
      "function" => {
        "name" => "web_search",
        "description" => "Search the web for current information. Use this for recent events, news, or topics that may have changed recently.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "query" => {
              "type" => "string",
              "description" => "The search query to look up on the web"
            }
          },
          "required" => ["query"],
          "additionalProperties" => false
        }
      }
    }.freeze

    # Batch processing tools
    BATCH_LIST_PROFILES = {
      "type" => "function",
      "function" => {
        "name" => "batch_list_profiles",
        "description" => "List all available batch processing profiles with their configurations.",
        "parameters" => {
          "type" => "object",
          "properties" => {},
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_CHECK_PATH = {
      "type" => "function",
      "function" => {
        "name" => "batch_check_path",
        "description" => "Check if a file or directory path exists and get information about it (type, size, etc.).",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "path" => {
              "type" => "string",
              "description" => "The file or directory path to check"
            }
          },
          "required" => ["path"],
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_RECENT_JOBS = {
      "type" => "function",
      "function" => {
        "name" => "batch_recent_jobs",
        "description" => "Get a list of recent batch processing jobs with their status.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "limit" => {
              "type" => "integer",
              "description" => "Maximum number of jobs to return (default: 5)"
            }
          },
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_START = {
      "type" => "function",
      "function" => {
        "name" => "batch_start",
        "description" => "Start a new batch processing job. Returns job ID and initial status.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "input_path" => {
              "type" => "string",
              "description" => "Path to input file or directory"
            },
            "mode" => {
              "type" => "string",
              "enum" => ["parallel", "sequential"],
              "description" => "Processing mode: parallel (async, 50% cost savings) or sequential (real-time, context passing)"
            },
            "model" => {
              "type" => "string",
              "description" => "Model to use (e.g., gpt-5-mini)"
            },
            "system_prompt" => {
              "type" => "string",
              "description" => "System prompt for all requests"
            },
            "profile" => {
              "type" => "string",
              "description" => "Name of saved profile to use"
            },
            "accumulation_mode" => {
              "type" => "string",
              "enum" => ["none", "append", "replace", "summary"],
              "description" => "Context passing mode for sequential processing"
            }
          },
          "required" => ["input_path"],
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_STATUS = {
      "type" => "function",
      "function" => {
        "name" => "batch_status",
        "description" => "Check the status of a batch job.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "job_id" => {
              "type" => "string",
              "description" => "The batch job ID"
            }
          },
          "required" => ["job_id"],
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_RESULT = {
      "type" => "function",
      "function" => {
        "name" => "batch_result",
        "description" => "Retrieve results from a completed batch job.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "job_id" => {
              "type" => "string",
              "description" => "The batch job ID"
            },
            "format" => {
              "type" => "string",
              "enum" => ["text", "json", "summary"],
              "description" => "Output format (default: summary)"
            }
          },
          "required" => ["job_id"],
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_CREATE_INPUT_FILE = {
      "type" => "function",
      "function" => {
        "name" => "batch_create_input_file",
        "description" => "Create an input file for batch processing from a list of prompts.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "prompts" => {
              "type" => "array",
              "items" => { "type" => "string" },
              "description" => "List of prompts to process"
            },
            "output_path" => {
              "type" => "string",
              "description" => "Path where to save the input file"
            }
          },
          "required" => ["prompts", "output_path"],
          "additionalProperties" => false
        }
      }
    }.freeze

    BATCH_SAVE_PROFILE = {
      "type" => "function",
      "function" => {
        "name" => "batch_save_profile",
        "description" => "Save a batch processing profile for reuse.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "name" => {
              "type" => "string",
              "description" => "Profile name"
            },
            "model" => {
              "type" => "string",
              "description" => "Model to use"
            },
            "system_prompt" => {
              "type" => "string",
              "description" => "System prompt"
            },
            "max_tokens" => {
              "type" => "integer",
              "description" => "Max tokens per response"
            }
          },
          "required" => ["name"],
          "additionalProperties" => false
        }
      }
    }.freeze

    # File operation tools (with security restrictions)
    FILE_READ = {
      "type" => "function",
      "function" => {
        "name" => "file_read",
        "description" => "Read the contents of a file. Only files in the current working directory or allowed paths can be read.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "path" => {
              "type" => "string",
              "description" => "Path to the file to read"
            },
            "max_lines" => {
              "type" => "integer",
              "description" => "Maximum number of lines to read (default: 100)"
            }
          },
          "required" => ["path"],
          "additionalProperties" => false
        }
      }
    }.freeze

    FILE_WRITE = {
      "type" => "function",
      "function" => {
        "name" => "file_write",
        "description" => "Write content to a file. Only files in the current working directory or allowed paths can be written.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "path" => {
              "type" => "string",
              "description" => "Path to the file to write"
            },
            "content" => {
              "type" => "string",
              "description" => "Content to write to the file"
            },
            "append" => {
              "type" => "boolean",
              "description" => "Append to file instead of overwriting (default: false)"
            }
          },
          "required" => ["path", "content"],
          "additionalProperties" => false
        }
      }
    }.freeze

    FILE_LIST = {
      "type" => "function",
      "function" => {
        "name" => "file_list",
        "description" => "List files and directories in a path.",
        "parameters" => {
          "type" => "object",
          "properties" => {
            "path" => {
              "type" => "string",
              "description" => "Directory path to list (default: current directory)"
            },
            "pattern" => {
              "type" => "string",
              "description" => "Glob pattern to filter files (e.g., *.txt)"
            }
          },
          "additionalProperties" => false
        }
      }
    }.freeze

    # Tool collections by category
    SEARCH_TOOLS = [WIKIPEDIA_SEARCH, WEB_SEARCH].freeze

    BATCH_TOOLS = [
      BATCH_LIST_PROFILES,
      BATCH_CHECK_PATH,
      BATCH_RECENT_JOBS,
      BATCH_START,
      BATCH_STATUS,
      BATCH_RESULT,
      BATCH_CREATE_INPUT_FILE,
      BATCH_SAVE_PROFILE
    ].freeze

    FILE_TOOLS = [FILE_READ, FILE_WRITE, FILE_LIST].freeze

    # All available tools
    ALL_TOOLS = (SEARCH_TOOLS + BATCH_TOOLS + FILE_TOOLS).freeze

    # Get tool definition by name
    # @param name [String] Tool name
    # @return [Hash, nil] Tool definition or nil if not found
    def self.get(name)
      ALL_TOOLS.find { |t| t.dig("function", "name") == name }
    end

    # Get tools by category
    # @param category [Symbol] Category name (:search, :batch, :file)
    # @return [Array<Hash>] Array of tool definitions
    def self.by_category(category)
      case category
      when :search then SEARCH_TOOLS
      when :batch then BATCH_TOOLS
      when :file then FILE_TOOLS
      else []
      end
    end
  end
end
