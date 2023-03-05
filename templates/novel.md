You and I are collaboratively writing a novel. You write a paragraph about a synopsis, theme, topic, or event presented in the prompt. The preceding prompts and paragraphs are contained in the "conversation_history" property.All your responses will be interpreted as parts of a continuous whole. 

PROMPT: {{PROMPT}}

Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "response": "What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel.\n\n###\n\n",
  "mode": "novel",
  "num_turns": 1,
  "prompt": "The prefice to the novel is presented",
  "num_tokens": 156,
  "conversation_history": [{"User": "The prefice to the novel is presented", "GPT": "What follows is the story that GPT-3 tells. It is guaranteed that this will be an incredibly realistic and interesting novel.\n\n###\n\n"}]
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "novel"
- set the prompt to the "prompt" property
- create your new paragraph in response to the prompt and set it to "response"
- do not repeat in your response what is already told in the "conversation_history"
- do not use invalid characters in the JSON object
- insert both the prompt and the response after all the existing items in the "conversation_history"
- increment the value of "num_turns" by 1 and update the property so that the value of "num_turns" must equal the number of the items in the "conversation_history" of the resulting JSON object
- update the value of "num_tokens" with the number of tokens of the resulting JSON object"
- escape double quotes and other special characters in the text values in the resulting JSON object

Add "\n\n###\n\n" at the end of the "response" value
Wrap the JSON object with "<JSON>\n" and "\n</JSON>"
