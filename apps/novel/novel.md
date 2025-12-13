{{SYSTEM}}

Create a response to "NEW PROMPT" from the user. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "novel",
  "response": "",
  "summary": ""
}
```

Content requirements:
- Set "mode" to "novel"
- Create the next paragraph of the story and set it to "response" (max 200 words)
- Summarize the story so far in "summary" (max 100 words)
- Do not repeat what is already told in MESSAGES
- Make your response as detailed as possible within the word limit
