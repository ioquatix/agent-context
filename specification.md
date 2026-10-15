# Agent Context Specification

## 1. Introduction

### 1.1 Purpose

Agent Context is a language-agnostic specification for providing and consuming contextual information from software packages to assist AI agents and other automated tools. This specification defines a standardized way for package authors to include supplementary documentation, examples, migration guides, and other contextual information that can be programmatically discovered and utilized.

### 1.2 Problem Statement

AI agents and automated tools working with software projects often lack access to the rich contextual information that package authors provide. While packages may have extensive documentation, examples, and best practices, this information is typically scattered across various sources and formats, making it difficult for automated tools to discover and utilize effectively.

### 1.3 Goals

- **Standardization**: Define a consistent structure for contextual information across different programming languages and ecosystems.
- **Discoverability**: Enable automated tools to programmatically find and access contextual information.
- **Separation of Concerns**: Clearly separate provider context from consumer context.
- **Extensibility**: Preserve additional provider-authored metadata alongside the fields defined by this specification.

## 2. Core Concepts

### 2.1 Context Provider

A **Context Provider** is any software package, library, or module that includes contextual information in its distribution. Context providers:

- Include a `context/` directory in their package root.
- Provide structured documentation and examples.
- Follow the file format specifications defined in this document.
- Version their context alongside their code.

### 2.2 Context Consumer

A **Context Consumer** is any project or tool that utilizes contextual information from its dependencies. Context consumers:

- Install context from their dependencies into a `.agents/context/` directory.
- May install skill-marked context documents into a `.agents/skills/` directory.
- Use tools to discover and access available context.
- Read and apply guidance relevant to the task.

### 2.3 Context Files

**Context Files** are structured documents that contain supplementary information about a package. They typically include:

- Documentation beyond basic API references.
- Configuration examples and templates.
- Migration guides between versions.
- Performance optimization tips.
- Security considerations.
- Troubleshooting guides.

A **Definition** is one installable unit loaded from a provider: an ordinary file, or a skill document together with its companion resources. A parsed **Document** represents the Markdown source and front matter of a definition. Files such as images and examples remain opaque.

A definition's **path** is its filename relative to the provider's `context/` directory, including any subdirectories and extension. Its **source path** locates the authored file in the installed package. A skill's **installed name** is its authored or derived `name`, used for its destination directory. These identifiers serve different purposes.

### 2.4 Context Installation

**Context Installation** is the process of copying context files from dependencies into a consumer's local context directory, making them available for use by tools and AI agents.

## 3. Directory Structure

### 3.1 Provider Directory: `context/`

Context providers MUST include a `context/` directory in their package root. This directory:

- **Location**: Must be at the top level of the package (same level as main source directories).
- **Purpose**: Contains all contextual information provided by the package.
- **Distribution**: Must be included in the package's distribution artifacts.
- **Versioning**: Must be versioned alongside the package code.

Example structure:

```
package-root/
├── context/
│   ├── getting-started.md
│   ├── configuration.md
│   ├── troubleshooting.md
│   └── migration/
│       └── v2-to-v3.md
├── src/
└── package.json
```

### 3.2 Consumer Directory: `.agents/context/`

Context consumers SHOULD create a `.agents/context/` directory in their project root to store installed context. This directory:

- **Location**: Must be at the project root (typically where package manifests are located).
- **Purpose**: Contains context files copied from dependencies.
- **Organization**: Must organize context by resolved provider in subdirectories named by a package selector.
- **Exclusion**: The generated `.agents/context/` directory SHOULD be excluded from version control. A Git integration SHOULD add local exclusions to `.git/info/exclude` so projects do not need to commit rules for generated files. Other project-owned files may live directly under `.agents/`.
- **Transient Nature**: Should contain only reproducible content that can be regenerated from installed packages and MUST NOT contain unique or modified files.

A package selector identifies one resolved provider. It is normally the package name. Consumers that support multiple resolved versions MUST distinguish them, for example with `package-a@1.0.0` and `package-a@2.0.0`. Tools SHOULD display accepted selectors when listing providers and use those selectors consistently in commands and installed directory names.

Example structure:

```
project-root/
├── .agents/context/
│   ├── package-a/
│   │   ├── getting-started.md
│   │   └── configuration.md
│   └── package-b/
│       └── troubleshooting.md
├── src/
└── package.json
```

### 3.3 Directory Separation Rationale

The separation between `context/` and `.agents/context/` serves several purposes:

- **Ownership**: `context/` is controlled by the project itself, `.agents/context/` contains external dependencies.
- **Isolation**: Prevents conflicts between different packages' context files.
- **Discoverability**: Makes it easy to find context for specific packages.
- **Maintenance**: Allows independent management of provided vs. consumed context.

## 4. Context File Format

### 4.1 File Extensions

Context files SHOULD use the following extensions:

- **`.md`**: Markdown files (primary format).
- **`.txt`**: Plain text files.
- **`.yaml`** or **`.yml`**: YAML configuration files.
- **`.json`**: JSON configuration files.

### 4.2 Markdown Context Files

Markdown files are the primary format for context files. They:

- MUST use valid Markdown syntax.
- SHOULD be named descriptively (e.g., `getting-started.md`, `configuration.md`).
- SHOULD include clear section headers for organization.

### 4.3 File Naming Conventions

Context files SHOULD follow these naming conventions:

- Use lowercase with hyphens for word separation.
- Be descriptive and specific.
- Group related files in subdirectories when appropriate.

Common file names:

- `getting-started.md`
- `configuration.md`
- `troubleshooting.md`
- `performance.md`
- `security.md`
- `migration-guide.md`

### 4.4 Skill Documents

A context provider may distribute an Agent Skill as a Markdown document directly inside `context/`. The document MUST use YAML front matter with `metadata.type: skill` and a non-empty top-level `description`:

```yaml
---
name: provider-workflow
description: Run the provider workflow when preparing a project.
metadata:
  type: skill
---
```

Within a context document's YAML `metadata` mapping, the string `skill` declares a skill. Consumers MUST treat all other `metadata.type` values, including absent, null, and unfamiliar values, as ordinary context. This allows providers to introduce new types while existing consumers continue installing their documents. Consumers MUST interpret only mappings as context metadata; other values of `metadata` are unrelated authored data and MUST be retained as ordinary context.

An authored top-level `name` MUST be preserved and used as the installed directory name. When `name` is absent, consumers MUST derive it from the lowercase provider package name (normalizing underscores to hyphens), a hyphen, and the source filename without its `.md` extension. Installed names MUST use lowercase ASCII letters, digits, and single hyphens, contain 1–64 characters, and begin and end with a letter or digit. Descriptions MUST contain 1–1,024 characters after trimming whitespace for validation; consumers MUST retain the authored description value.

Consumers MUST install the document as `.agents/skills/<name>/SKILL.md`. A companion directory named after the source filename without its extension MAY provide resources, independently of the installed name. Its files MUST be copied into the installed skill directory. Consumers MUST retain additional top-level fields and nested metadata, except for the resolved installation provenance defined in section 7. Skill documents and their resources belong exclusively to the installed skill.

Consumers MUST preserve the original Markdown body bytes following the front matter. Front matter formatting MAY be normalized during serialization.

Dependency-installed skill directories SHOULD be excluded from version control, while project-owned skills in `.agents/skills/` SHOULD remain trackable. Git integrations SHOULD add exact dependency-installed skill paths to `.git/info/exclude` rather than ignore the entire `.agents/skills/` directory. They SHOULD mark generated entries with comments and preserve user-authored rules outside that marked section.

## 5. Discovery and Installation

### 5.1 Discovery Process

Tools MUST be able to discover context by:

1. **Package Scanning**: Examining installed packages for `context/` directories.
2. **Metadata Extraction**: Reading package manifests to identify context-providing packages.
3. **File Enumeration**: Listing available context files for each package.

The discovery process SHOULD integrate with the target language's package management system to:

- Locate installed packages and their installation paths.
- Read package metadata to identify packages that provide context.
- Enumerate available context files within discovered packages.

### 5.2 Installation Process

Context installation MUST follow these principles:

1. **Copy Strategy**: Context files SHOULD be copied rather than symlinked.
2. **Namespace Isolation**: Each resolved provider's ordinary context MUST be installed in its own subdirectory, named by its package selector.
3. **Preserve Structure**: The internal structure of ordinary context files MUST be preserved.
4. **Skill Separation**: Skill documents and their resources MUST be installed as skills only, not duplicated as ordinary context.

Consumers SHOULD validate document data as part of loading or parsing it and use that validated representation when applying changes. Installation MAY use direct file writes and copies. Consumers MUST report failures; completed changes and partially written output MAY remain after an error. After resolving the reported failure, consumers SHOULD support refreshing generated output by rerunning installation.

### 5.3 Installation Steps

For each selected provider:

1. Classify its context documents and identify companion skill resource directories, keeping their contents opaque.
2. If skills are supported, install each declared skill once as `.agents/skills/<name>/SKILL.md` and copy its companion resources into that skill directory.
3. Copy the remaining ordinary files into `.agents/context/<selector>/`, preserving their relative paths.

Skill documents and their resources are excluded from ordinary context copying even when the consumer does not support skill installation.

## 6. Discovering Installed Context

Consumers SHOULD provide commands to list providers, list their definitions, and show a selected definition. Agents discover installed guidance by enumerating Markdown files under `.agents/context/<selector>/` and reading the files relevant to their task. A packaged usage skill SHOULD explain this workflow and how to install missing guidance.

Providers SHOULD use descriptive filenames, keep guides focused on one topic, and link related documents. Ordinary documents need no front matter. Unrelated ordinary-document metadata MUST be tolerated. Skill resource files are opaque assets and MUST NOT be parsed as context documents.

Provider lookup identifies dependencies with a `context/` directory, including empty directories. An empty provider has no definitions; listing commands MAY omit it from the available guidance list. Refreshing an empty provider still reconciles its installed output.

Showing a definition MUST return its authored content. Lookup MUST prefer an exact provider-relative path, then that path with `.md` appended when no extension was supplied. Consumers MAY also accept installed skill names as a fallback after source path lookup. Definition paths retain their filename case and extension. Generated skill instructions add installation provenance when installed.

The installed directory layout is the discovery interface.

## 7. Skill Installation Ownership

Consumers MUST record resolved installation provenance inside `SKILL.md` front matter:

```yaml
---
name: provider-workflow
description: Run the provider workflow when preparing a project.
metadata:
  type: skill
  ecosystem: cargo
  package: provider
  version: "1.0.0"
---
```

The installer supplies `metadata.ecosystem`, `metadata.package`, and `metadata.version` from its resolved provider, overriding source values for these fields. Ruby gems use `gem`; Cargo crates use `cargo`. These three fields MUST be non-empty strings, including a quoted version when YAML would otherwise decode it as a number. Additional metadata MUST be retained.

Consumers MUST discover ownership by scanning direct child directories of `.agents/skills/` and parsing their `SKILL.md` files. The skills root and managed skill directories MUST be regular directories. Symbolic links and non-directory children are skipped. Instruction files MUST be regular files. Managed directory names MUST satisfy section 4.4.

`metadata.type: skill` together with an explicit `metadata.ecosystem` identifies installation provenance. Consumers MUST validate the complete provenance tuple after recognizing that discriminator, and report malformed or unreadable metadata. Other directories are project-owned; an authored `metadata.version` alone is ordinary skill metadata.

A full refresh reconciles the installer's ecosystem; a package refresh reconciles that ecosystem and package. Full reconciliation includes providers removed from the dependency graph and providers that become empty. Consumers MUST retain skills belonging to other ecosystems and packages outside the requested scope, and MUST reject conflicting destinations.

Installers SHOULD write `SKILL.md` before copying companion resources, establishing ownership for subsequent refreshes. If writing the instructions fails, installers SHOULD remove that incomplete destination. Resource-copy failures leave completed instructions in place. The incremental failure behavior in section 5.2 applies to skills and Git exclusion updates.

The top-level resource name `SKILL.md` is reserved case-insensitively for generated instructions. Consumers MUST reject a resource file or directory with that name. Nested files with that name and other resource names are copied as opaque assets.

Git integrations SHOULD maintain one marked exclusion block per consuming project, covering generated context and exact dependency-owned skill directories from all ecosystems. Exclusion paths MUST be relative to the Git repository root. Nested projects SHOULD identify their block by appending the repository-relative project path, with a trailing slash, to the `# BEGIN bake-agent-context` and `# END bake-agent-context` markers. They MUST retain user-authored rules and blocks belonging to other projects. Installed instructions and resources are excluded with their containing skill directory.
