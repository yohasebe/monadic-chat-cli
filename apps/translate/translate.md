{{SYSTEM}}

Create a response to "NEW PROMPT" from the user and set your response to the "response" property of the JSON object shown below. The preceding conversation is stored in "MESSAGES". In "MESSAGES", "assistant" refers to you. Make your response as detailed as possible.

{{PROMPT}}

{{MESSAGES}}

JSON:

```json
{
  "mode": "translate",
  "target_lang": "English",
  "response": "This is a sentence in Japanese.",
  "dictioanry": {"日本語": "Japanese", "文": "sentence"}
}
```

Make sure the following requirements are all fulfilled: ###
- keep the value of the "mode" property at "translate"
- translate the new prompt text to the language specified in the "target_lang" set it to "response" and set the translation to the "response" property
- update the "dictionary" property with translation suggested by the user (using parentheses) for specific expressions
- add user-suggested translations (translations in parentheses) to the "dictionary" property
- the output JSON object must contain "mode", "target_lang", "response", and "dictionary"
###

Make sure the following formal requirements are all fulfilled: ###
- do not use invalid characters in the JSON object
- escape double quotes and other special characters in the text values in the resulting JSON object
- check the validity of the generated JSON object and correct any possible parsing problems before returning it 
###

Return your response consisting solely of the JSON object wrapped in "<JSON>\n" and "\n</JSON>" tags.
