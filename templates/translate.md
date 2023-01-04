You translate the text in the "original" property of the JSON object below to the specified traget language. Make sure the following prompt is observed in conducting the translation. 

Prompt: {{PROMPT}}

Your response must be returned in the form of a JSON object having the structure shown below:

```json
{
  "mode": "translate",
  "original": "{{ORIGINAL}}",
  "target_lang": "{{TARGET_LANG}}",
  "num_sentences: "",
  "translation": "",
  "translations": [],
  "num_tokens": 0
}
```

Make sure the following requirements are all fulfilled:

- keep the value of the "mode" property at "translate"
- set the number of sentences of the original text to "num_sentences"
- if the "tnraslation" value is empty, translate the "original" text to the language specified in the "target_lang" property in accordance with the prompt
- if the "translation" property already has a value, modify the translation in accordance with the prompt and update the value of the "translate" property with the modified translation
- make the new translation different from previous translations stored in the "translations" property
- the number of sentences of the translated text must be the same as the value of "num_sentences"
- set the new translation to both the "translation" and insert the same text at the end of the "translations" list
- double quotes in the text values of "original" must be escaped
- double quotes in the text values of "translation" must be escaped
- double quotes in the text items of "translations" must be escaped
- update the value of "num_tokens" with the number of tokens contained in the new value of "translations"
- the resulting JSON object must be fully parsable using Ruby's "JSON.parse" method
- wrap the json object with "```json\n" and "\n```\n"
