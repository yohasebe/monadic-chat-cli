# Native Tool Use API

Monadic Chat CLI supports OpenAI's native tool use (function calling) API, allowing apps to define and execute tools through JSON Schema definitions.

## Overview

Instead of pattern-based tool detection (e.g., `SEARCH_WIKI("query")`), apps can now use OpenAI's native function calling mechanism which provides:

- **Structured tool definitions** using JSON Schema
- **Automatic tool execution loop** with up to 10 iterations
- **Parallel tool execution** for multiple simultaneous tool calls
- **Backward compatibility** with legacy pattern-based detection

## Enabling Tools in Apps

To enable native tool use in a MonadicApp subclass, use the `enable_tools` class method:

```ruby
class MyApp < MonadicApp
  enable_tools :search          # Wikipedia + Web search
  enable_tools :batch           # Batch processing tools
  enable_tools :file            # File operation tools
  enable_tools :all             # All available tools
end
```

### Available Tool Categories

| Category | Tools Included |
|----------|---------------|
| `:search` | `wikipedia_search`, `web_search` |
| `:wikipedia` | `wikipedia_search` only |
| `:web` | `web_search` only |
| `:batch` | 8 batch processing tools |
| `:file` | `file_read`, `file_write`, `file_list` |
| `:all` | All 13 tools |

## Tool Definitions

All tools are defined in `lib/monadic_chat/tool_definitions.rb` using JSON Schema format compatible with OpenAI's API.

### Search Tools

#### `wikipedia_search`
Search Wikipedia for factual information.

```json
{
  "name": "wikipedia_search",
  "parameters": {
    "query": { "type": "string", "description": "Search query (in English)" }
  },
  "required": ["query"]
}
```

#### `web_search`
Search the web for current information.

```json
{
  "name": "web_search",
  "parameters": {
    "query": { "type": "string", "description": "Search query" }
  },
  "required": ["query"]
}
```

### Batch Tools

| Tool | Description | Required Parameters |
|------|-------------|---------------------|
| `batch_list_profiles` | List saved batch profiles | None |
| `batch_check_path` | Check if path exists | `path` |
| `batch_recent_jobs` | Get recent batch jobs | None (optional: `limit`) |
| `batch_start` | Start a batch job | `input_path` |
| `batch_status` | Check job status | `job_id` |
| `batch_result` | Get job results | `job_id` |
| `batch_create_input_file` | Create input file from prompts | `prompts`, `output_path` |
| `batch_save_profile` | Save a batch profile | `name` |

### File Tools

| Tool | Description | Required Parameters |
|------|-------------|---------------------|
| `file_read` | Read file contents | `path` |
| `file_write` | Write content to file | `path`, `content` |
| `file_list` | List directory contents | None (optional: `path`, `pattern`) |

## Security Restrictions

File operations are restricted for security:

### Allowed Paths
- Current working directory
- `~/Downloads`
- `~/Documents`
- `~/.monadic_chat`

### Size Limits
- Read: Maximum 1MB per file
- Write: Maximum 100KB per operation

### Path Traversal Prevention
- Paths containing `..` are rejected
- All paths are expanded to absolute paths before validation

## Tool Execution Flow

1. **User Input**: User sends a message
2. **API Call**: Request sent to OpenAI with tool definitions
3. **Tool Call Detection**: Check if response contains `tool_calls`
4. **Tool Execution**: Execute each tool and collect results
5. **Result Submission**: Send tool results back to API
6. **Loop or Complete**: Repeat until no more tool calls (max 10 iterations)

```
User Input
    ↓
┌─────────────────────────────────────┐
│  API Call with tools parameter      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Response received                  │
│  - Has tool_calls? → Execute tools  │
│  - No tool_calls? → Return response │
└─────────────────────────────────────┘
    ↓ (if tool_calls)
┌─────────────────────────────────────┐
│  Execute tools in parallel          │
│  Add results to messages            │
└─────────────────────────────────────┘
    ↓
    Loop (max 10 iterations)
```

## Adding Custom Tools

To add a new tool:

1. **Define the tool** in `lib/monadic_chat/tool_definitions.rb`:

```ruby
MY_TOOL = {
  "type" => "function",
  "function" => {
    "name" => "my_tool",
    "description" => "Description of what the tool does",
    "parameters" => {
      "type" => "object",
      "properties" => {
        "param1" => {
          "type" => "string",
          "description" => "Parameter description"
        }
      },
      "required" => ["param1"],
      "additionalProperties" => false
    }
  }
}.freeze
```

2. **Implement execution** in `lib/monadic_chat/tool_executor.rb`:

```ruby
def execute_tool(tool_name, arguments)
  case tool_name
  when "my_tool"
    execute_my_tool(arguments)
  # ... other tools
  end
end

def execute_my_tool(arguments)
  param1 = arguments["param1"]
  # Implementation here
  JSON.generate({ "result" => "..." })
end
```

3. **Register the tool category** in `lib/monadic_app.rb`:

```ruby
def enable_tools(*tool_sets)
  # ...
  when :my_category
    @registered_tools << MonadicChat::ToolDefinitions::MY_TOOL
  # ...
end
```

## Backward Compatibility

Apps that don't call `enable_tools` continue to work with the legacy pattern-based tool detection:

- `SEARCH_WIKI("query")` → Wikipedia search
- `SEARCH_WEB("query")` → Web search

The system checks for native tool calls first, then falls back to pattern matching if no native tools are registered or the model doesn't support them.

## Model Requirements

Native tool use requires models with `tool_capability: true` in the model specification. This includes:

- GPT-5 series (gpt-5, gpt-5-mini, gpt-5-nano, etc.)
- GPT-4 series with function calling support
- O-series reasoning models

For models without tool support, the system automatically falls back to pattern-based detection.

## Testing

Unit tests for native tool use are in `spec/unit/native_tool_use_spec.rb`, covering:

- Tool definition structure and JSON Schema compliance
- Tool registration and category management
- Tool call extraction from API responses
- Security restrictions validation

Run tests with:
```bash
bundle exec rspec spec/unit/native_tool_use_spec.rb
```
