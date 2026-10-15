# Agent Context Design

The Ruby `agent-context` gem and Rust `bake-agent-context` crate share a portable installation contract. The [specification](specification.md) defines file formats and observable behavior; this guide maps the implementation responsibilities.

Choose the simplest structure that makes the behavior, state, and responsibilities easy to follow.

## Responsibilities

| Concern | Ruby | Rust |
| --- | --- | --- |
| Resolved package specification | `Gem::Specification`, retained by `Package` | `Specification`, resolved by `Installer::discover` |
| Parsed Markdown | `Document` | `Document` in `document.rs` |
| Loaded provider | `Package` wrapping `Gem::Specification` | `Package` wrapping `Specification` |
| Provider lookup | `Installer#providers`, `#find_provider` | `Installer::providers`, `find_provider` |
| Definition lookup | `Package#find_definition` | `Package::find_definition` |
| Ordinary file | `Definition` | `FileDefinition` |
| All definition variants | `Definition` and `Skills::Definition < Definition` | `Definition::File(FileDefinition)` or `Definition::Skill(SkillDefinition)` |
| Installation workflow | `Installer#install` | `Installer::install` |
| Installed provenance | `Skills::Ownership` | `ownership` module |
| Local Git exclusions | `Exclusion` | `exclude` module |
| Command presentation | Bake task adapters | Bake task adapters |
| Errors | `Agent::Context::Error`, `InvalidError`, `ConflictError` | `bake::Error` returned through `Result` |

Each parser, metadata rule, and file format has one owner. Document parsing interprets Markdown and YAML; skill definitions apply name and description rules; ownership interprets installed provenance; installers select destinations and change files. Constructors retain supplied state. Reading, parsing, discovery, and installation have explicit entry points.

Ruby's loaded `Package` retains its `Gem::Specification` and definitions. Rust's resolved `Specification` carries Cargo metadata and the context path; loaded `Package` wraps that specification with its definitions. Both apply the same document and installation rules.

Ruby uses the gem name as its package selector. Rust uses the crate name when unique and `crate@version` when multiple versions provide context. These selectors identify providers in commands and installed context directories. “Provider” is the domain role of a package that supplies context. Both installers expose `providers` and `find_provider`, returning loaded packages. A provider with an existing empty `context/` directory has an empty definition collection; a dependency without that directory is absent from provider lookup. Listing commands show providers with available definitions. Rust additionally exposes resolved Cargo metadata through `specifications` and `find_specification`.

## Documents and Front Matter

`Document.load(path)` and `Document::load(path)` read the source and delegate to `parse`. The parsed value retains the source path, original Markdown, decoded YAML mapping, and the Markdown parser's front matter node or source boundary.

Both implementations use their Markdown parser's front matter node to read and serialize front matter: Markly in Ruby and `socketry-markdown` in Rust. The document layer decodes and encodes YAML through the node's raw value and classifies context using the nested `metadata.type` field. The skill predicate matches `skill`; all other values follow the ordinary context path. Only a `metadata` mapping is interpreted as context metadata; other authored values remain intact in the source. Ordinary guides can carry their own top-level fields. Front matter uses YAML by default or with the explicit `yaml` language hint. Other front matter languages remain opaque.

A skill definition validates its top-level name and description. It preserves an authored name and uses it for the installed directory. When the name is omitted, it derives `<package>-<filename>`. Resource directories follow the source filename. Description validation trims whitespace to measure the value; the authored value is retained.

To generate installed instructions, the definition merges resolved `ecosystem`, `package`, and `version` into the nested metadata mapping and supplies a missing name. The document writes the YAML into a copy of its front matter AST node and asks the Markdown library to serialize that node. It appends the original body using the parser's source boundary. Links, code blocks, spacing, Unicode, and body line endings retain their original bytes.

The portable YAML form uses `---` delimiters. Rust also recognizes the additional front matter forms supported by `socketry-markdown`, such as a leading YAML code fence, and retains their delimiter style. Markly's supported syntax defines the Ruby parsing boundary.

## Discovery and Loading

For each provider, load Markdown documents before descending into subdirectories. Root-level skill declarations identify companion resource directories. Keep those resources opaque, including Markdown-looking assets.

The loaded package stores ordinary definitions and skills in one collection. Ruby uses `Definition` for ordinary files and `Skills::Definition < Definition` for skills. Rust represents the same alternatives with a `Definition` enum: `File(FileDefinition)` carries the provider-relative destination path, source path, and optional parsed `Document`; `Skill(SkillDefinition)` carries skill-specific metadata and resources. Both implementations use `Document` for parsed Markdown.

Listing, showing, and installation use this classification. Each definition's `path` is relative to the provider's `context/` directory; `source_path` locates the authored file. A skill's `name` identifies its installed directory. Definition lists are ordered by source path.

`Package.find_definition(file)` checks the exact source path, then appends `.md` when no extension was given, and finally checks installed skill names. The lookup uses the loaded definitions. `content` and the `show` command return authored content for every definition. Skill definitions retain their parsed `Document` and resolved specification, and expose generated instructions as `installation_content`.

The main installation operation resolves providers and loads each provider once, then applies the ordinary or skill destination rules to each definition. `Package.install_files(destination)` refreshes ordinary files in a package directory. A skill definition's `install(destination)` writes generated instructions and resources into its skill directory. Ruby's ordinary `Definition#write_to(path)` writes authored content to a file path, including when called on a skill definition.

## Installation Flow

The library owns orchestration. Bake tasks translate arguments, call the library, and present installed provider and skill names. Installation results contain package selectors under `context` and plain installed skill names under `skills`; presentation formatting belongs in task adapters.

1. Resolve the selected providers and load their definitions.
2. Validate and install skills under `.agents/skills/`, reconcile stale entries within the selected scope, and refresh Git exclusions.
3. Install ordinary definitions under `.agents/context/`.

Generated files use direct `File.write` or `std::fs::write`. Completed steps remain in place if a later operation fails. Report the relevant path and let the caller resolve the failure and rerun. Cleanup around a failed instruction write removes the incomplete destination; a later resource-copy failure retains the completed instructions and their provenance.

Loading and writing are separate operations over a loaded snapshot. `Document.load(path).write(destination)` expresses that contract. Installation is a local, rerunnable workflow with incremental progress.

## Ownership and Git Exclusions

Installed `SKILL.md` metadata carries the resolved ecosystem, package, and version. Scanning direct skill directories supplies the names used for reconciliation and local Git exclusions. Ownership recognition requires `metadata.type: skill` and an explicit ecosystem before validating the complete tuple. Project skills can use unrelated metadata such as a version without claiming installation ownership.

A full refresh selects one ecosystem; a package refresh selects one ecosystem and package. Destination collisions are reported. Other owned scopes and project skills remain available.

Git exclusion handling locates and reads the local exclusion file, replaces the consuming project's marked block, and writes the result directly. Prefixes distinguish nested projects sharing a repository. The block lists generated context and exact installed skill directories from all ecosystems.

## Readability and Verification

Multi-step operations group related calculations and effects under short behavioral comments, separated by blank lines. Method documentation explains single-step operations. Helpers represent distinct responsibilities or independently meaningful operations.

Both implementations exercise the shared `SKILL.md` fixture. Compare decoded metadata for format rules and exact body bytes for preservation. Tests cover classification, authored and derived names, metadata preservation, ownership scopes, opaque resources, Git exclusions, failures, and a successful retry. Keep the specification and this component mapping aligned when behavior or responsibilities change.
