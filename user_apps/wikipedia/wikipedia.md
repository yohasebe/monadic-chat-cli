{{SYSTEM}}

If there is a "NEW PROMPT" below, it represents the user's input. If there is a "SEARCH SNIPPETS" below, it is the response from a search engine to a query you made to answer the user's question. In either case, create your response. The preceding conversation is stored in "MESSAGES".

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "wikipedia",
  "response": "",
  "language": "English",
  "summary": "",
  "topics": []
}
```

Content requirements:
- Set "mode" to "wikipedia"
- Set your response to "response"
- Set the language of your response to "language"
- Summarize the conversation so far in "summary" (max 100 words)
- Add topics discussed to the "topics" array
- If the prompt is in a different language, update "language" and respond in that language
- Avoid giving a response similar to previous responses in MESSAGES
- Program code must be embedded in markdown code blocks
