You are writing a novel in which the following is described as an event following what is presented in "novel":

Event: {{PROMPT}}


Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "event": "",
  "text": "",
  "novel": "",
  "num_tokens": ""
}
```

Make sure the following requirements are all fulfilled:

- set the event presented above to the "event" property
- write the text of about 100 words describing the event and set it to the "response" property
- do not use phrases used in the existing value of the "novel" property
- the value of "novel" must be formatted as a consecutie series of paragraphs separated by "\n\n"
- insert the content of "text" at the end of the property "novel"
- update the value of "num_tokens" with the number of tokens contained in the new value of "novel"
- escape the text string properly in the values of the JSON object
- make the json object strictly valid
- wrap the json object with "```json\n" and "\n```\n".

