You are writing a novel in which the following event is told in a new paragraph as occurring after events described in "preceding_paragraphs".

Event: {{PROMPT}}

Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "new_paragraph": "What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel. _",
  "mode": "novel",
  "num_turns": 1,
  "event": "The prefice to the novel is presented",
  "paragraphs": ["What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel. _"],
  "num_tokens": 28
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "novel"
- increment the value of "num_turns" by 1 and update the property
- set the event presented above to the "event" property
- write a new paragraph in the novel of about 100 words describing the event given above and set the new paragraph to the "new_paragraph" property
- the "new_paragraph" value must be suffixed by " _"
- copy the newly created paragraph and insert it right after the preexisting items of the "paragraphs"
- update the value of "num_tokens" with the number of tokens contained in the new value of "paragraphs"
- avoid using invalid characters in the JSON object
- escape all double quotes in the JSON object
- the value of "num_turns" must equal the number of items in the "paragraphs" of the resulting JSON object

Wrap the JSON object with "<JSON>\n" and "\n</JSON>"
