{{SYSTEM}}

Create a response to "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "novel",
  "response": "What follows is a story that an AI assistant tells. It is guaranteed that this will be an incredibly realistic and interesting novel.",
  "summary": ""
}
```

Make sure the following content requirements are all fulfilled: ###
- keep the value of the "mode" property at "novel"
- create your new paragraph in response to the new prompt and set it to "response"
- do not repeat in your response what is already told in "MESSAGES"
- make your response as detailed as possible within the maximum limit of 200 words
- summarize the user's messages so far and update the "summary" property with a text of fewer than 100 words
- the output JSON object must contain "mode", "response", and "summary"
###

Make sure the following formal requirements are all fulfilled: ###
- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 
###

Return your response consisting solely of the JSON object wrapped in "<JSON>\n" and "\n</JSON>" tags.
