# Kruk AI chatbot

## Overview

Kruk is a multi-purpose chatbot built in Perl. It has both predefined commands as well as AI interaction.

## Core Characteristics

- command interface which contains useful tools and lets users inspect AI state
- AI has access to some useful tools, like fetching a website and noting stuff down
- AI can read chat which was not directed at it (on demand), to help with ongoing discussions
- multiple AI personalities, which can be switched by the user
- multiple languages (for system messages and commands)

## Integrations

Currently, the bot can operate in the following environments:

- IRC
- CLI

## Requirements

- perl 5.40. Dependencies from `cpanfile` are best installed with Carmel
- needs database to store state, either SQLite or PostgreSQL
- Anthropic API key with some credit balance
- database migrations are developed with `sqitch` (from App::Sqitch)
- deployment script uses `rex` (from Rex)

## License

BSD 2-Clause

