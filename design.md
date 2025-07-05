# Design Document: agent-context

## Problem Statement

AI agents working with Ruby codebases often lack access to the rich contextual information that gem authors provide. While gems may have extensive documentation, examples, migration guides, and best practices, this information is typically scattered across READMEs, wikis, blog posts, and other sources that aren't easily accessible to AI agents.

## Core Design Principles

### 1. Context as a First-Class Concept

Context files are treated as a first-class part of a gem's public interface, alongside the code itself. This means:
- Context files are versioned with the gem.
- They're distributed as part of the gem package.
- They're discoverable and accessible programmatically.
- They follow a consistent structure and format.

### 2. Machine-Readable, Human-Friendly

Context files use `.md` (Markdown Context) format, which combines:
- **Human readability**: Standard Markdown for easy authoring and reading.
- **Machine structure**: YAML frontmatter for metadata and organization.
- **Extensibility**: Can include code examples, diagrams, and structured data.

### 3. Separation of Concerns

The design separates three distinct concerns:
- **Public Interface**: `context/` directory in gem root (what gem authors provide).
- **Private Working Directory**: `.context/` in consuming projects (where context is installed).
- **Tool Interface**: `bake agent:context:*` commands (how users interact).

## Architecture Decisions

### File Organization Strategy

**Decision**: Context files are installed into `.context/gem-name/` subdirectories

**Rationale**:
- **Isolation**: Prevents conflicts between different gems' context files.
- **Discoverability**: Easy to find context for a specific gem.
- **Scalability**: Supports installing context from multiple gems.
- **Clear Ownership**: Obvious which context files belong to which gem.

### Command Structure

**Decision**: Use `bake agent:context:*` command namespace

**Rationale**:
- **Consistency**: Matches the gem name `agent-context`.
- **Clarity**: Makes it obvious these commands are for AI agent workflows.
- **Namespace Safety**: Avoids conflicts with other gem-related commands.
- **Tool Integration**: Leverages existing Bake infrastructure.

### Module Structure

**Decision**: Use `Agent::Context` module namespace

**Rationale**:
- **Purpose Clarity**: Explicitly indicates this is for AI agents.
- **Namespace Safety**: Avoids potential conflicts with RubyGems' `Gem::` namespace.
- **Future-Proof**: Won't conflict if RubyGems adds their own context features.

## Context File Design

### YAML Frontmatter

Context files support structured metadata:
```yaml
---
description: Short summary of the file's purpose
globs: "test/**/*.rb,lib/**/*.rb"  # Comma-separated file patterns
alwaysApply: false                  # Whether to always apply this context
---
```

**Design Decisions**:
- **`description`**: Required human-readable summary.
- **`globs`**: Optional file patterns this context applies to.
- **`alwaysApply`**: Optional flag for context that should always be available.
- **No tags**: Keeps the format simple and focused.

### File Naming Conventions

- **`.md` extension**: Indicates Markdown Context files.
- **Descriptive names**: `thread-safety.md`, `performance.md`, `migration-guide.md`.
- **Fallback support**: Commands can find files with or without extensions.

## Installation Strategy

### Copy vs. Symlink

**Decision**: Copy files rather than symlink

**Rationale**:
- **Offline Access**: Context remains available even if gems are uninstalled.
- **Version Stability**: Context doesn't change if gem is updated.
- **Project Independence**: Context becomes part of the project's knowledge base.
- **Simplicity**: No symlink management or broken link issues.

### Directory Structure

```
project/
├── .context/           # Private working directory
│   ├── async/         # Context from async gem
│   │   ├── thread-safety.md
│   │   └── performance.md
│   └── rails/         # Context from rails gem
│       └── configuration.md
```

## Use Cases and Workflows

### For Gem Authors

1. **Create Context Directory**: Add `context/` to gem root.
2. **Write Context Files**: Create `.md` files with documentation, examples, guides.
3. **Version and Distribute**: Context files are included in gem releases.

### For Developers

1. **Discover Context**: `bake agent:context:list` to see available context.
2. **Install Context**: `bake agent:context:install --gem async` to copy locally.
3. **Access Context**: AI agents can read from `.context/` directory.

### For AI Agents

1. **Scan Context**: Read from `.context/` directory for relevant information.
2. **Apply Context**: Use glob patterns to determine which context applies.
3. **Provide Guidance**: Reference gem-specific documentation and examples.

## Future Considerations

### Potential Enhancements

- **Context Validation**: Validate `.md` file structure and content.
- **Context Indexing**: Create searchable index of installed context.
- **Context Updates**: Mechanism to update context when gems are updated.
- **Context Dependencies**: Allow context files to reference other context files.

### Integration Opportunities

- **IDE Integration**: Context-aware code completion and documentation.
- **CI/CD Integration**: Validate context files during gem releases.
- **Documentation Sites**: Generate context-aware documentation.
- **AI Agent Frameworks**: Direct integration with AI agent platforms.

## Conclusion

The `agent-context` gem provides a simple but powerful mechanism for making Ruby gems more AI-friendly. By treating context as a first-class part of a gem's interface, it enables AI agents to access the rich knowledge that gem authors provide, leading to more effective and informed code assistance. 