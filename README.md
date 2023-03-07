<img src="./doc/img/monadicchat.png" width="480px"/>

Highly configurable CLI client app for OpenAI's chat/text-completion API

## Table of Contents

<!-- vim-markdown-toc GFM -->

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Using RubyGems](#using-rubygems)
  - [Clone the GitHub repository](#clone-the-github-repository)
- [Usage](#usage)
  - [Authentication](#authentication)
  - [Select App](#select-app)
- [System-Wide Features](#system-wide-features)
- [Apps](#apps)
  - [Chat](#chat)
  - [Code](#code)
  - [Novel](#novel)
  - [Translation](#translation)
- [Modes](#modes)
  - [Normal Mode](#normal-mode)
  - [Research Mode](#research-mode)
- [How Research Mode Works](#how-research-mode-works)
  - [Accumulator](#accumulator)
  - [Implementation of Reducer](#implementation-of-reducer)
- [Creating New Apps](#creating-new-apps)
  - [Folder/File Structure](#folderfile-structure)
  - [Case Study: `Parsing` App](#case-study-parsing-app)
- [What is Monadic about Monadic Chat?](#what-is-monadic-about-monadic-chat)
- [Todo](#todo)
- [References](#references)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

<!-- vim-markdown-toc -->

## Introduction

**Monadic Chat** is a command-line client application program that uses OpenAI's Text Completion API and Chat API to enjoy chat-style conversations with OpenAI's artificial intelligence system in a ChatGPT-like style.

The conversation with the AI can be saved in a JSON file, and the saved JSON file can be loaded later to continue the conversation. The conversation data can also be converted to HTML format and displayed in a web browser.

Monadic Chat comes with four apps (`Chat`, `Code`, `Novel`, and `Translate`). Each can generate a different kind of text through interactive interaction between the user and OpenAI's large-scale language model. Users can also create their own apps.

## Prerequisites

- Ruby 2.6.10 or greater
- OpenAI API Token
- Any command line terminal app such as:
  - Terminal or [iTerm2](https://iterm2.com/) (MacOS)
  - [Windows Terminal](https://apps.microsoft.com/store/detail/windows-terminal) (Windows 11)
  - GNOME Terminal (Linux)
  - [Alacritty](https://alacritty.org/) (Multi-platform)

## Installation

### Using RubyGems

Execute the following command in an environment where Ruby 2.6 or higher is installed.

```
gem install monadic_chat
```

### Clone the GitHub repository

Alternatively, clone the code from the GitHub repository and follow the steps below to install it. At this time, you must take this option to create a new app for Monadic Chat's `research` mode or to use other advanced features.

1. Clone the repo

```
git clone https://github.com/yohasebe/monadic-chat.git
```

2. Install dependencies

```
cd monadic-chat
bundle update
```

3. Grant permission to the executable file

```
chmod +x ./bin/monadic
```

4. Run the executable file

```
./bin/monadic
```

## Usage

### Authentication

When you start Monadic Chat with the `monadic` command, you will be asked for an OpenAI access token. If you do not have one, create an account on the [OpenAI](https://platform.openai.com/) website and obtain an access token.

If the environment variable `OPENAI_API_KEY` is set in the system, its value will be used automatically.

<img src="./doc/img/input-acess-token.png" width="760px"/>

Once the correct access token is verified, the access token is saved in the configuration file below and will automatically be used the next time the app is started.

`$HOME/monadic_chat.conf`

### Select App

Upon successful authentication, a menu to select a specific app will appear. Each app generates different types of text through an interactive chat-style conversation between the user and the AI. Four apps are available by default: `Chat`, `Code`, `Novel`, and `Translate`. Please check the links for the functions and usage of each app.
By selecting the `Mode` menu item, you can change the mode of Monadic Chat from `Normal` to `Research` and vice versa. Please check the links for the features and functions of each mode.

Selecting `Readme` will take you to the README on the Github repository (which is the document you are looking at now). Selecting `Quit` will exit the Monadic Chat app.

<img src="./doc/img/select-app-menu.png" width="760px"/>

In the app menu, you can use the cursor keys to make a selection and the enter key to make a decision. You can also narrow down the choices each time you type a letter.

## System-Wide Features

Each utterance in the conversation that unfolds in each app is labeled with one of three roles: `User`, `GPT`, or `System`.

- `User`: utterances from the user of the Monadic Chat app (that's you!)
- `GPT`: utterances from the Open AI large-scale language model
- `System`: messages from the Monadic Chat system

You can call up the function menu in the middle of a conversation with the AI. To invoke the function menu, type `help` at the prompt or press `CTRL-L`.

<img src="./doc/img/select-feature-menu.png" width="760px"/>

In the function menu, you can use the cursor keys to make a selection and the enter key to make a decision. You can also narrow down the choices each time you type a letter. Some functions are given multiple names so that typing on the keyboard will quickly bring up the function you need.

**params/settings/config**

You can set parameters to be sent to OpenAI's text completion AI and chat API. The items that can be set are listed below. For more information on each parameter, please refer to Open AI's [API Documentation](https://platform.openai.com/docs/). The default value of each parameter depends on the individual "mode" or "app".

- `model`
- `max_tokens`
- `temperature`
- `top_p`
- `frequency_penalty`
- `presence_penalty`

**data/context**

In `normal` mode, running this function only displays the history of conversation so far between User and GPT. In `research` mode, meta-information (e.g. topics, language being used, number of turns)values are presented.

In `research` mode, it may take several seconds to several minutes after the `data/context` command is executed before the actual data is displayed. This is because in `research` mode, even after displaying a direct response to user input, there may be a process running in the background that retrieves the context data and reconstructs it as needed, requiring the system to wait for it to finish.

**html**

All the information retrieved by running `data/context` function is presented in an HTML format. The HTML file is automatically opened in the default web browser.

In `research` mode, it may take several seconds to several minutes after the `html` command is executed before the acutal HTML is displayed. This is because in `research` mode, even after displaying a direct response to user input, there may be a process running in the background that retrieves the context data and reconstructs it as needed, requiring the system to wait for it to finish.

**reset**

Resets all the conversation history (messages by both User and GPT). API parameter settings are reset to default as well.

**save and load**

The current conversation history (messages by both User and GPT, and meta information in case of `research` mode) can be saved as a JSON file in a path specified by the user. The saved file can only be read by the same application that saved it.

**clear/clean**

Scrolls down so that the cursor comes to the top of the screen

**readme/documentation**

Takes you to the README on the Github repository (which is the document you are looking at now).

**exit/bye/quit**

Exits the Monadic Chat app.

## Apps

### Chat

Monadic Chat's `Chat` is the most basic and generic app among others offered by default. As with ChatGPT, there can be many variations in the content of the conversation. In the `Chat` app, OpenAI's large-scale language model acts as a competent assistant that can do anything. It can write computer code, create fiction and poetry texts, and translate texts from one language into another. Of course, it can also engage in casual or academic discussions on specific topics.

- The JSON instructions for this app's behavior in `normal` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/normal/chat.json).
- The Markdown instructions for this app's behavior in `research` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/research/chat.md).

### Code

Monadic Chat's `Code` is designed to be an app that has artificial intelligence write computer programs. In the `Code` app, OpenAI's large language model behaves as a competent software engineer. The main difference from the `Chat` app is that the `temperature` parameter is set to `0.0`, so that as less randomness as possible is introduced to the responses. Syntax highlighting is applied (where possible) to the program code contained in the GPT responses. The same is true for the output via the `html` command available from the functions menu.

- The JSON instructions for this app's behavior in `normal` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/normal/code.json).
- The Markdown instructions for this app's behavior in `research` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/research/code.md).

### Novel

Monadic Chat's `Novel` is designed to have artificial intelligence create novels; the `Novel` application instructs OpenAI's large-scale language model to create more detailed sentences based on a topic, theme, or brief description of an event indicated by the user. GPT is instructed to create a new response based on what it generated in previous responses. The app allows the user to interact with GPT and control the plot, rather than having the AI create a new novel all at once.

- The JSON instructions for this app's behavior in `normal` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/normal/novel.json).
- The Markdown instructions for this app's behavior in `research` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/research/novel.md).

### Translation

Monadic Chat's `Translation` is an app that assists in translating text written in one language into another. Rather than translating the entire text at once, the app allows users to translate in stages and make any necessary adjustments. Users can specify the expressions they would like GPT to use in parentheses ( ) in the source text. For problematic translations, the user can "save" the set of source and target texts and make the necessary corrections. By giving the app the corrected translation data, similar unwanted expressions can be prevented or avoided.

- The JSON instructions for this app's behavior in `normal` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/normal/translation.json).
- The Markdown instructions for this app's behavior in `research` mode can be found [here](https://github.com/yohasebe/monadic-chat/blob/main/templates/research/translation.md).

## Modes

Monadic Chat has two modes. The `normal` mode utilizes OpenAI's chat API to achieve ChatGPT-like functionality and is suitable for using a large language model as a competent companion to achieve various goals. On the other hand, `research` mode utilizes OpenAI's text-completion API. Since this mode allows for the acquisition of various metadata at each turn of the conversation, it can be used as a platform for the linguistic (especially pragmatic) examination of how the natural language dialogues unfold

### Normal Mode

In `normal` mode, Open AI's chat API is used. The default language model is `gpt-3.5-turbo`.

In the default configuration, after 10 turns, the dialogue logs are deleted from the oldest ones (the first message given as default by the `system` role is the first turn, which is deleted first).

If you wish to specify how contextual inheritance is to be performed in a dialog between USER and GPT, you can do so by writing a Proc object that encapsulates a Ruby function. However, fine-grained control is not possible in this mode due to the lack of available metadata.

### Research Mode

In `research` mode, Open AI's text-completion API is used. The default language model is `text-davinci-003`.

Although the text-completion API is not a system optimized for chat-style dialogue, it can be used in conjunction with a mechanism for inputting and outputting contextual information in a monad structure to realize an interactive dialogue system. Such a mechanism also has the advantage that various metadata can be obtained at each turn of the dialogue.

In the default configuration, when the number of tokens in the response from the GPT (which includes contextual information and thus increases with each turn) reaches a certain value, the oldest messages are deleted.

If you wish to specify how contextual inheritance is to be performed in a dialog between USER and GPT, you can do so by writing a Proc object that encapsulates a Ruby function. Since various meta-information is available in this mode, finer-grained control is possible (documentation in progress).

## How Research Mode Works

Monadic Chat's `research` mode has the following drawbacks

- It uses OpenAI's `text-davinci-003` model and the response from the AI is not as detailed as in the `normal` mode that uses `gpt-3.5-turbo`
- After displaying a direct response to user input, contextual information is processed in the background, which can cause lag when referring to conversation history and the like
- Templates are larger and more complex in `research` mode and it requires more efort to create and fine-tun.
- Compared to `normal` mode, `research` mode has larger input/output and consumes more tokens
- Compared to the chat API used in `normal` mode, the text-completion API used in `research` mode is more expensive.

However, Monadic Chat has `research` mode for the following reasons

- in `research` mode, each turn of the conversation can capture metadata as well as the main responses
- can control the flow of the conversation based on the captured metadata as well as the conversation history
- has an overall structure that mimics the monadic nature of natural language discourse

<img src="./doc/img/how-research-mode-works.svg" width="900px"/>

### Accumulator

*In preparation*

### Implementation of Reducer

*In preparation*

## Creating New Apps

This section describes how users can create their own original Monadic Chat app.

### Folder/File Structure

Monadic Chat apps are placed in the `apps` folder. The folders and files for default apps `chat`, `code`, `novel` and `translate` are also placed in this folder. To create a new app, create a new folder inside `apps`.

```
apps
├── chat
│   ├── chat.json
│   ├── chat.md
│   └── chat.rb
├── code
│   ├── code.json
│   ├── code.md
│   └── code.rb
├── novel
│   ├── novel.json
│   ├── novel.md
│   └── novel.rb
└─── translate
    ├── translate.json
    ├── translate.md
    └── translate.rb
```

Notice in the figure above that three files with the same name but different extensions (`.rb`, `.json`, and `.md`) are stored under their respective folders. Similarly, when creating a new app, you create these three types of files under a folder with the same name as the app name, as shown below.

```
apps
└─── app_name
    ├── app_name.json
    ├── app_name.md
    └── app_name.rb
```

The purpose of each file is as follows.

- `app_name.rb`: Ruby code to control the conversation log and flow of the dialog
- `app_name.json`:JSON template file describing GPT behavior in `normal` mode
- `app_name.md`:Markdown template file describing GPT behavior in `research` mode

The `.rb` file is required, but you may create both `.json` and `.md` files, or only one of them. See the next section on how to write these files.

Folders beginning with `_` and their contents are ignored. Template files with a name beginning with `_` are also ignored.

### Case Study: `Parsing` App

*In preparation*

## What is Monadic about Monadic Chat?

A monad is a type of data structure in functional programming (leaving aside for the moment the notion of monad in mathematical category theory). An element with a monadic structure can be manipulated in a certain way to change its internal data. However, no matter how much the internal data changes, the external structure of the monadic element remains the same and can be manipulated in exactly the same way as it was at first.

We are surrounded by many such monadic entities, and natural language discourse is one of them. A "chat" between a human user and an AI can be thought of as a form of natural language discourse, which is monadic in nature. If so, an application that provides an interactive interface to a large-scale language model, such as ChatGPT, would most naturally be designed in a "functional" way, taking into account the monadic nature of natural language discourse.

There are many "functional" programming languages, such as Haskell, that have monads as a core feature. However, Monadic Chat was developed using the Ruby programming language. This is because with Ruby, it would be easier for users to write their own apps (in the author's rather subjective opinion). It is true that Ruby, which incorporates some features of functional languages, is not classified as a "functional language." Monadic Chat has the following three features required of a monad, and in this sense, it can be considered "monadic."

- ***unit*** : a monad framework has a means of taking data and enclosing it in a monad structure 
- ***bind*** : a monadic framework has a means of performing some operation on the data and enclosing the result in a monad structure
- ***join*** : a monad framework has a means of flattening a structure with multiple monad layers into a single layer 

## Todo

- Improved error handling mechanisms
- Development of DSL to define GPT behavior
- Scafolding feature to quickly build new apps

## References

I would appreciate it if you would use one of the following Bibtex entries when referring to Monadic Chat.

```
@misc{rsyntaxtree_2023,
  author = {Yoichiro Hasebe},
  title = { Highly configurable CLI client app for OpenAI’s chat/text-completion API }
  url = {https://github.com/yohasebe/monadic-chat},
  year = {2023}
}
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/yohasebe/monadic_chat]([https://github.com/yohasebe/monadic_chat]).

## Author

Yoichiro Hasebe

[yohasebe@gmail.com](yohasebe@gmail.com)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
