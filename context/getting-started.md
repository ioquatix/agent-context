# Getting Started

## What is this?

`agent-context` is a tool that helps you discover and install contextual information from Ruby gems for AI agents. Gems can provide additional documentation, examples, and guidance in a `context/` directory.

## Quick Commands

```bash
# See what context is available
bake agent:context:list

# Install all available context
bake agent:context:install

# Install context from a specific gem
bake agent:context:install --gem async

# See what context files a gem provides
bake agent:context:list --gem async

# View a specific context file
bake agent:context:show --gem async --file thread-safety
```

## What happens when you install context?

When you run `bake agent:context:install`, the tool:

1. Scans all installed gems for `context/` directories
2. Creates a `.context/` directory in your current project
3. Copies context files organized by gem name

For example:
```
your-project/
├── .context/
│   ├── async/
│   │   ├── thread-safety.md
│   │   └── performance.md
│   └── rack/
│       └── middleware.md
```

## Why use this?

- **Discover hidden documentation** that gems provide
- **Get practical examples** and guidance
- **Understand best practices** from gem authors
- **Access migration guides** and troubleshooting tips

