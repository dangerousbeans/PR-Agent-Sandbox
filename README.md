## AI Agent Manager

A Ruby framework for managing AI coding agents that process GitHub issues.

## Setup

1. Copy `config.yml.example` to `config.yml` and fill in your GitHub credentials (and OpenAI API key if you plan to use the remote chat API).
2. Install Ruby dependencies:
   ```bash
   bundle install
   ```
3. Install the local `codex` CLI for on-device code generation:
   ```bash
   npm install -g codex
   ```
4. Ensure you have `git` installed and your GitHub token has the correct permissions. Verify that `codex` is available in your `PATH`.

## Usage

```bash
bin/agent_manager
```

This will start the issue watcher and spawn the configured number of agents.

## Configuration

See `config.yml.example` for available settings.

## Extending the Framework

Customize `CodexClient#generate_patch` to improve patch generation logic based on your needs.