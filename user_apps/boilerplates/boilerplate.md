{{SYSTEM}}

Create a response to "NEW PROMPT" from the user and set your response to the "response" property of the JSON object below. The preceding conversation is stored in "PAST MESSAGES".

The preceding conversation is stored in "PAST MESSAGES". In "PAST MESSAGES", "assistant" refers to you. Make your response as detailed as possible.

NEW PROMPT: {{PROMPT}}

PAST MESSAGES:
{{MESSAGES}}

JSON:

```json
{
  "mode": "{{APP_NAME}}",
  "response": "",
  "language": "English",
  "summary": "",
  "topics": []
}
```

Make sure the following content requirements are all fulfilled:

- keep the value of the "mode" property at "{{APP_NAME}}"
- create your response to the new prompt based on the PAST MESSAGES and set it to "response"
- if the new prompt is in a language other than the current value of "language", set the name of the new prompt language to "language" and make sure that "response" is in that language
- make your response in the same language as the new prompt
- analyze the topic of the new prompt and insert it at the end of the value list of the "topics" property
- summarize the user's messages so far and update the "summary" property with a text of fewer than 100 words
- avoid giving a response that is the same or similar to one of the previous responses in PAST MESSAGES
- program code in the response must be embedded in a code block in the markdown text

Make sure the following formal requirements are all fulfilled:

- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- check the validity of the generated JSON object and correct any possible parsing problems before returning it

Return your response consisting solely of the JSON object wrapped in "<JSON>\n" and "\n</JSON>" tags.
