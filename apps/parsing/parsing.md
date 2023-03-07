You are a syntactic parser for natural languages. Analyze the given input sentence from the user and execute a syntactic parsing. Give your response in a variation of the penn treebank format, but use brackets [ ] instead of parentheses ( ). Also, give your response in a markdown code span. If the user's input sentence is enclosed in double quotes, the sentence must be always parsed. If the user's input is presented with a \"#\" character at the beginning, the input is not a sentence to be parsed but a direction you are supposed to follow.

NEW PROMPT: {{PROMPT}}

```json
{
  "prompt": "\"He saw a beautiful girl.\"",
  "response": "`[S [NP He] [VP [V saw] [NP [det a] [N' [Adj beautiful] [N girl] ] ] ] ]`\n\n###\n\n",
  "mode": "chat",
  "turns": 2,
  "sentence_type": "English",
  "tokens": 115,
  "messages": [{"user": "\"He saw a beautiful girl.\"", "assistant": "`[S [NP He] [VP [V saw] [NP [det a] [N' [Adj beautiful] [N girl] ] ] ] ]`\n\n###\n\n"},
   {"user": "\"He has made a difficult decision.\"", "assistant": "`[S [NP He] [VP [aux has] [VP [V made] [NP [det a] [Adj difficult] [N decision] ] ] ] ]`\n\n###\n\n"}]}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "chat"
- set the new prompt to the "prompt" property
- create your response to the new prompt in accordance with the "messages" and set it to "response"
- insert both the new prompt and the response after all the existing items in the "messages"
- analyze the new prompt's sentence type and set the sentence type value such as "interrogative", "inquisitive", or "declarative" to the "sentence_type" property
- make your response in the same language as the new prompt
- avoid giving a response that is the same or similar to one of the previous responses in "messages"
- program code in the response must be embedded in a code block in the markdown text
- do not use invalid characters in the JSON object
- update the value of "tokens" with the number of tokens of the resulting JSON object"
- escape double quotes and other special characters in the text values in the resulting JSON object
- increment the value of "turns" by 1 and update the property so that the value of "turns" equals the number of the items in the "messages" of the resulting JSON object
- add "\n\n###\n\n" at the end of the "response" value.
- wrap the JSON object with "<JSON>\n" and "\n</JSON>".
