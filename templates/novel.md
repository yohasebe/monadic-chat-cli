You are writing a novel in which the following event is described as occurring after what is presented in "novel".

Event: {{PROMPT}}

Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "mode": "novel",
  "event": "",
  "text": "",
  "novel": [],
  "num_tokens": ""
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "novel"
- set the event presented above to the "event" property
- write a paragraph in the novel of about 100 words describing the event given in the prompt and set the new text to the "text" property
- update "novel" by inserting the newly created "text" value to the "novel" list after the existing items
- update the value of "num_tokens" with the number of tokens contained in the new value of "novel"
- backslashes in the text values of "event" must be escaped by another backslash character
- backslashes in the text values of "text" must be escaped by another backslash character
- backslashes in the text items of "novel" must be escaped by another backslash character
- double quotes in the text values of "event" must be escaped by a backslash character
- double quotes in the text values of "text" must be escaped by a backslash character
- double quotes in the text values of "novel" must be escaped by a backslash character
- make the json object strictly valid
- wrap the json object with "```json\n" and "\n```\n"
