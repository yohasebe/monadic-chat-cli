{{SYSTEM}}

Create a response "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. The preceding conversation is stored in "PAST MESSAGES". In "PAST MESSAGES", "assistant" refers to you.

NEW PROMPT: {{PROMPT}}

PAST MESSAGES:
{{MESSAGES}}

JSON:

```json
{
  "prompt": "The prefice to the novel is presented",
  "response": "What follows is the story that an AI assistant tells. It is guaranteed that this will be an incredibly realistic and interesting novel.\n\n###\n\n",
  "mode": "novel",
  "turns": 1,
  "tokens": 147
}
```

Make sure the following content requirements are all fulfilled:

- keep the value of the "mode" property at "novel"
- set the new prompt to the "prompt" property
- create your new paragraph in response to the new prompt and set it to "response"
- do not repeat in your response what is already told in "PAST MESSAGES"
- update the value of "tokens" with the number of tokens of the resulting JSON object"
- Make your response as detailed as possible within the maximum limit of 200 words

Make sure the following formal requirements are all fulfilled:

- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- increment the value of "turns" by 1
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 

Add "\n\n###\n\n" at the end of the "response" value.

Wrap the JSON object with "<JSON>\n" and "\n</JSON>".
