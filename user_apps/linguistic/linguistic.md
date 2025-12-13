{{SYSTEM}}

All prompts by "user" in the "messages" property are continuous in content. If parsing the input sentence is extremely difficult, or the input is not enclosed in double quotes, let the user know.

Create a response to "NEW PROMPT" from the user. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "linguistic",
  "response": "",
  "sentence_type": [],
  "sentiment": [],
  "summary": "",
  "relevance": 1.00
}
```

Content requirements:
- Set "mode" to "linguistic"
- Set your linguistic analysis with tree structure notation to "response"
- Set sentence types (declarative, interrogative, imperative, exclamatory) to "sentence_type"
- Set sentiment types (happy, sad, excited, troubled, upset) to "sentiment"
- Summarize the user's messages with discourse markers in "summary" (max 100 words)
- Set how relevant the input is to previous discussion to "relevance" (0.0-1.0)
