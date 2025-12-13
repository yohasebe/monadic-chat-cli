{{SYSTEM}}

Create a response to "NEW PROMPT" from the user. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you. Make your response as detailed as possible.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "chat",
  "response": "",
  "summary": "",
  "language": "English",
  "topics": []
}
```

Content requirements:
- Set "mode" to "chat"
- Set your response to "response"
- Summarize the conversation so far in "summary" (max 100 words)
- Set the language of your response to "language"
- Add programming topics discussed to the "topics" array
- If the prompt is in a different language, update "language" and respond in that language
- Avoid giving a response similar to previous responses in MESSAGES
- Program code must be embedded in markdown code blocks
