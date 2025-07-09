# Agent::Context

Provides tools for installing and managing context files from Ruby gems for AI agents, and generating `agent.md` files following the <https://agent.md> specification.

[![Development Status](https://github.com/ioquatix/agent-context/workflows/Test/badge.svg)](https://github.com/ioquatix/agent-context/actions?workflow=Test)

## Overview

This gem allows you to install and manage context files from other gems. Gems can provide context files in a `context/` directory in their root, which can contain documentation, configuration examples, migration guides, and other contextual information for AI agents.

When you install context from gems, they are placed in the `.context/` directory and an `agent.md` file is generated or updated to provide a comprehensive overview for AI agents.

## Quick Start

Add the gem to your project and install context from all available gems:

```bash
$ bundle add agent-context
$ bake agent:context:install
```

This workflow:
- Adds the `agent-context` gem to your project.
- Installs context files from all gems into `.context/`.
- Generates or updates `agent.md` with a comprehensive overview.
- Follows the <https://agent.md> specification for agentic coding tools.

## Context

This gem provides its own context files in the `context/` directory, including:

- `usage.md` - Comprehensive guide for using and providing context files.

When you install context from other gems, they will be placed in the `.context/` directory and referenced in `agent.md`.

## Usage

### Installation

Add the `agent-context` gem to your project:

```bash
$ bundle add agent-context
```

### Commands

#### Install Context (Primary Command)

Install context from all available gems and update `agent.md`:

```bash
$ bake agent:context:install
```

Install context from a specific gem:

```bash
$ bake agent:context:install --gem async
```

#### List available context

List all gems that have context available:

```bash
$ bake agent:context:list
```

List context files for a specific gem:

```bash
$ bake agent:context:list --gem async
```

#### Show context content

Show the content of a specific context file:

```bash
$ bake agent:context:show --gem async --file thread-safety
```

## Version Control

Both `.context/` and `agent.md` should be committed to git:

- `agent.md` is user-facing documentation that should be versioned.
- `.context/` files are referenced by `agent.md` and needed for AI agents to function properly.
- This ensures AI agents in CI have access to the full context.

## Providing Context in Your Gem

To provide context files in your gem, create a `context/` directory in your gem's root:

```
your-gem/
├── context/
│   ├── getting-started.md
│   ├── usage.md
│   ├── configuration.md
│   └── index.yaml (optional)
├── lib/
└── your-gem.gemspec
```

### Optional: Custom Index File

You can provide a custom `index.yaml` file to control ordering and metadata:

```yaml
description: "Your gem description from gemspec"
version: "1.0.0"
files:
  - path: getting-started.md
    title: "Getting Started"
    description: "Quick start guide"
  - path: usage.md
    title: "Usage Guide"
    description: "Detailed usage instructions"
```

If no `index.yaml` is provided, one will be generated automatically from your gemspec and markdown files.

## AI Tool Integration

The generated `agent.md` file can be integrated with various AI coding tools by creating symbolic links to their expected locations:

### Cline
```bash
ln -s agent.md .clinerules
```

### Claude Code
```bash
ln -s agent.md CLAUDE.md
```

### Cursor
```bash
ln -s agent.md .cursorrules
```

### Gemini CLI, OpenAI Codex, OpenCode
```bash
ln -s agent.md AGENTS.md
```

### GitHub Copilot
```bash
ln -s ../../agent.md .github/copilot-instructions.md
```

### Replit
```bash
ln -s agent.md .replit.md
```

### Windsurf
```bash
ln -s agent.md .windsurfrules
```

## See Also

  - [Bake](https://github.com/ioquatix/bake) — The bake task execution tool.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
