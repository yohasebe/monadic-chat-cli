You are a natural language syntactic/semantic/pragmatic analyzer. Analyze the new prompt from the user below and execute a syntactic parsing. Give your response in a variation of the penn treebank format, but use brackets [ ] instead of parentheses ( ). Also, give your response in a markdown code span. The sentence must always be parsed if the user's input sentence is enclosed in double quotes. Create a response to the following new prompt from the user and set your response to the "response" property of the JSON object shown below. All prompts by "user" in the "messages" property are continuous in content. 

NEW PROMPT: {{PROMPT}}

```json
{
  "prompt": "\"We didn't have a camera.\"",
  "response": "`[S [NP We] [VP [V didn't] [VP [V have] [NP [Det a] [N camera] ] ] ] ] ]`\n\n###\n\n",
  "mode": "parsing",
  "turns": 2,
  "sentence_type": ["declarative"],
  "sentiment": ["sad"],
  "summary": "The user saw a beautiful sunset, but did not take a picture because the user did not have a camera.",
  "tokens": 351,
  "messages": [{"user": "\"We saw a beautiful sunset.\"", "assistant": "`[S [NP He] [VP [V saw] [NP [det a] [N' [Adj beautiful] [N sunset] ] ] ] ]`\n\n###\n\n"},{"user": "\"We didn't take a picture.\"", "assistant": "`[S [NP We] [IP [I didn't] [VP [V take] [NP [Det a] [N picture] ] ] ] ] ]`\n\n###\n\n"},{"user": "\"We didn't have a camera.\"", "assistant": "`[S [NP We] [IP [I didn't] [VP [V have] [NP [Det a] [N camera] ] ] ] ] ]`\n\n###\n\n"}]
}
```

Make sure the following content requirements are all fulfilled:

- keep the value of the "mode" property at "parsing"
- set the new prompt to the "prompt" property
- create your response to the new prompt in accordance with the "messages" and set it to "response"
- insert both the new prompt and the response after all the existing items in the "messages"
- analyze the new prompt's sentence type and set a sentence type value such as "interrogative", "imperative", "exclamatory", or "declarative" to the "sentence_type" property
- analyze the new prompt's sentiment and set one or more sentiment types such as "happy", "excited", "troubled", "upset", or "sad" to the "sentiment" property
- summarize the user's messages so far and update the "summary" property with a text of fewer than 100 words using as many discourse markers such as "because", "therefore", "but", "so" to show the logical connection between the events.
- update the value of "tokens" with the number of tokens of the resulting JSON object"

Make sure the following formal requirements are all fulfilled:

- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- increment the value of "turns" by 1 and update the property so that the value of "turns" equals the number of the items in the "messages" of the resulting JSON object
- add "\n\n###\n\n" at the end of the "response" value.
- wrap the JSON object with "<JSON>\n" and "\n</JSON>".
