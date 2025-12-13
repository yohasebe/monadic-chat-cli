## [Unreleased]

## [0.6.0] - 2024-12-13

### Added
- Support for OpenAI's Responses API (`/v1/responses`)
- GPT-5 series models: gpt-5, gpt-5-mini, gpt-5-nano, gpt-5-pro, gpt-5-chat-latest
- GPT-5.1 series models: gpt-5.1, gpt-5.1-chat-latest, gpt-5.1-codex, gpt-5.1-codex-mini, gpt-5.1-codex-max
- GPT-5.2 series models: gpt-5.2, gpt-5.2-chat-latest, gpt-5.2-pro
- Model-specific parameter handling (reasoning_effort, verbosity)
- Expensive model confirmation for high-cost models (*-pro series)
- Model specifications synced from Monadic Chat (non-CLI)

### Changed
- Default models updated: `gpt-5-mini` (normal mode), `gpt-5` (research mode)
- UI limited to GPT-5 series models only
- Reasoning models use reasoning_effort instead of temperature/top_p
- Verbosity parameter available for supported GPT-5 models
- Increased max_tokens: 8000 (research mode), 2000 (normal mode)

### Removed
- frequency_penalty and presence_penalty parameters (use API defaults)
- Support for older models in UI (GPT-4 series still work via config file)

## [0.1.0] - 2023-01-03

- Initial commit (private)

## [0.1.3] - 2023-03-12

- Public release
- Authentication problem fixed

## [0.2.0] - 2023-03-13

- Research mode architecture changed
- Stability improvement

## [0.2.1] - 2023-03-21

- GPT-4 models supported (in `normal` mode)

## [0.3.0] - 2023-03-24

- `Research` mode now supports chat API in addition to text-completion API

## [0.3.3] - 2023-03-26

- Command line options to directly run individual apps

## [0.3.4] - 2023-04-02

- Architecture refined here and there

## [0.3.5] - 2023-04-05

- `Wikipedia` app added (experimental)
- `monadic-chat new/del app_name` command added

## [0.3.7] - 2023-10-08

- Default model changed to `gpt-3.5-turbo-0613`
- Stability improvement

## [0.4.0] - 2023-11-10

- Default model changed to `gpt-3.5-turbo`
- Support for OpenAI's latest models
- Missing character issue addressed
- API access timeout/retry mechanism improved

## [0.4.1] - 2024-01-27

- New models of January 2024 supported
- Default model changed to `gpt-4`

## [0.4.2] - 2024-02-09

- Issue of redundant token addition addressed
- Default model changed to `gpt-3.5-turbo-0125`

## [0.4.3] - 2024-05-13

- `gpt-4o` set as default model for both `normal` and `research` modes

## [0.4.4] - 2024-07-18

- `gpt-4o-mini` set as default model for `normal` mode

## [0.4.5] - 2024-08-07
- `gpt-4o-2024-08-06` set as the default model for `research` mode

## [0.4.6b] - 2024-08-15
- `gpt-4o-2024-08-06` set as the default model for `research` mode again
