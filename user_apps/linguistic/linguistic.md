{{SYSTEM}}

All prompts by "user" in the "messages" property are continuous in content. If parsing the input sentence is extremely difficult, or the input is not enclosed in double quotes, let the user know.

Create a response to "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "response": "`[S [NP We] [VP [V didn't] [VP [V have] [NP [Det a] [N camera] ] ] ] ] ]`",
  "mode": "linguistic",
  "sentence_type": ["declarative"],
  "sentiment": ["sad"],
  "summary": "The user saw a beautiful sunset, but did not take a picture because the user did not have a camera.",
  "relevance": 0.80
}
```

Make sure the following content requirements are all fulfilled: ###
- keep the value of the "mode" property at "linguistic"
- create your response to the new prompt based on "PMESSAGES" and set it to "response"
- analyze the new prompt's sentence type and set a sentence type value such as "interrogative", "imperative", "exclamatory", or "declarative" to the "sentence_type" property
- analyze the new prompt's sentiment and set one or more sentiment types such as "happy", "excited", "troubled", "upset", or "sad" to the "sentiment" property
- summarize the user's messages so far and update the "summary" property with a text of fewer than 100 words using as many discourse markers such as "because", "therefore", "but", and "so" to show the logical connection between the events.
- update the value of the "relevance" property indicating the degree to which the new input is naturally interpreted based on previous discussions, ranging from 0.0 (extremely difficult) to 1.0 (completely easy)
###

Make sure the following formal requirements are all fulfilled: ###
- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 
###

Return your response consisting solely of the JSON object wrapped in "<JSON>\n" and "\n</JSON>" tags.
