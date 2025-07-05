# Agent::Context

Provides tools for installing and managing context files from Ruby gems for AI agents.

[![Development Status](https://github.com/ioquatix/agent-context/workflows/Test/badge.svg)](https://github.com/ioquatix/agent-context/actions?workflow=Test)

## Overview

This gem allows you to install and manage context files from other gems. Gems can provide context files in a `context/` directory in their root, which can contain documentation, configuration examples, migration guides, and other contextual information.

## Context

This gem provides its own context files in the `context/` directory, including:

- `adding-context.md` - Guide for adding context files to gems.
- `examples.md` - Examples of context file usage.
- `getting-started.md` - Getting started guide.

When you install context from other gems, they will be placed in the `.context/` directory.

## Usage

### Installation

Add the `agent-context` gem to your project:

``` bash
$ bundle add agent-context
```

### Commands

#### List available context

List all gems that have context available:

``` bash
$ bake agent:context:list
```

List context files for a specific gem:

``` bash
$ bake agent:context:list --gem async
```

#### Show context content

Show the content of a specific context file:

``` bash
$ bake agent:context:show --gem async --file thread-safety
```

#### Install context

Install context from all available gems:

``` bash
$ bake agent:context:install
```

Install context from a specific gem:

``` bash
$ bake agent:context:install --gem async
```

This will create a `.context/` directory in your project with the installed context files organized by gem name.

## Providing Context in Your Gem

To provide context files in your gem, create a `context/` directory in your gem's root:

    your-gem/
    ├── context/
    │   ├── thread-safety.md
    │   ├── performance.md
    │   └── migration-guide.md
    ├── lib/
    └── your-gem.gemspec

Context files can be in any format, but markdown (`.md`) files are commonly used for documentation.

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
