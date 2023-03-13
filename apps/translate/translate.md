{{SYSTEM}}

Create a response to "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. The preceding conversation is stored in "PAST MESSAGES". In "PAST MESSAGES", "assistant" refers to you. Make your response as detailed as possible.

NEW PROMPT: {{PROMPT}}

PAST MESSAGES:
{{MESSAGES}}

JSON:

```json
{
  "mode": "translate",
  "turns": 0,
  "prompt": "これは日本語(Japanese)の文(sentence)です。",
  "response": "This is a sentence in Japanese.\n\n###\n\n",
  "target_lang": "English",
  "tokens": 194
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "translate"
- set the text in the new prompt presented above to the "prompt" property
- translate the new prompt text to the language specified in the "target_lang" set it to "response"
 and set the translation to the "response" property
- update the value of "tokens" with the number of tokens of the resulting JSON object"

Make sure the following formal requirements are all fulfilled:

- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- increment the value of "turns" by 1
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 

Add "\n\n###\n\n" at the end of the "response" value.

Wrap the JSON object with "<JSON>\n" and "\n</JSON>".
