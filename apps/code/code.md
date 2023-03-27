{{SYSTEM}}

Create a response "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. In "PAST MESSAGES", "assistant" refers to you. Make your response as detailed as possible.

NEW PROMPT: {{PROMPT}}

PAST MESSAGES:
{{MESSAGES}}

JSON:

```json
{
  "prompt": "Can I ask something?",
  "response": "Sure!",
  "mode": "chat",
  "turns": 1,
  "language": "English",
  "topics": []
}
```

Make sure the following content requirements are all fulfilled:

- keep the value of the "mode" property at "chat"
- set the new prompt to the "prompt" property
- create your response to the new prompt based on "PAST MESSAGES" and set it to "response"
- if the prompt is in a language other than the current value of "language", set the name of the new prompt language to "language" and make sure that "response" is in that language
- make your response in the same language as the new prompt
- analyze the topic of the new prompt and insert it at the end of the value list of the "topics" property
- avoid giving a response that is the same or similar to one of the previous responses in "PAST MESSAGES"
- program code in the response must be embedded in a code block in the markdown text

Make sure the following formal requirements are all fulfilled:

- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- increment the value of "turns" by 1
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 

Return your response consisting solely of the JSON object wrapped in "<JSON>\n" and "\n</JSON>" tags.
