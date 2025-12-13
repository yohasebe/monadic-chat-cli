{{SYSTEM}}

Create a response to "NEW PROMPT" from the user. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "translate",
  "target_lang": "English",
  "response": "",
  "dictionary": {}
}
```

Content requirements:
- Set "mode" to "translate"
- Translate the new prompt text to the language specified in "target_lang"
- Set the translated text to "response"
- Add user-suggested translations (in parentheses) to the "dictionary" object
