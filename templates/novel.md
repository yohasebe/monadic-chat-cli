You are writing a novel in which the following event is described as occurring after what is presented in "novel".

Event: {{PROMPT}}

Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "mode": "novel",
  "event": "The prefice to the novel is presented",
  "paragraph": "What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel.",
  "novel": ["What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel."],
  "num_tokens": 28
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "novel"
- remove unnecessary "\n" from your response 
- set the event presented above to the "event" property
- write a paragraph in the novel of about 100 words describing the event given as the prompt and set the new paragraph to the "paragraph" property
- insert the newly created "paragraph" value at the end of the "novel" list
- update the value of "num_tokens" with the number of tokens contained in the new value of "novel"
- the resulting JSON object must be fully parsable using Ruby's "JSON.parse" method
- avoid useing invalid characters in the JSON object
- all the newline characters must be "\n"

Wrap the json object with "<JSON>\n" and "\n</JSON>"
