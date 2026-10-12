# Agent Context Design

The Ruby `agent-context` gem and Rust `bake-agent-context` crate share a portable installation contract. The [specification](specification.md) defines file formats and observable behavior; this guide maps the implementation responsibilities.

Choose the simplest structure that makes the behavior, state, and responsibilities easy to follow.

## Responsibilities

| Concern | Ruby | Rust |
| --- | --- | --- |
| Resolved provider | `Gem::Specification`, retained by `Package` | `ContextPackage`, resolved by `Installer::discover` |
| Parsed Markdown | `Document` | `ContextDocument` in `document.rs` |
| Loaded provider definitions | `Package#definitions` | `PackageContext::definitions` |
| Ordinary definition | `Definition` | `Definition::File` |
| Skill definition | `Skills::Definition < Definition` | `Definition::Skill` |
| Installation workflow | `Installer#install` | `Installer::install` |
| Installed provenance | `Skills::Ownership` | `ownership` module |
| Local Git exclusions | `Exclusion` | `exclude` module |
| Command presentation | Bake task adapters | Bake task adapters |

Each parser, metadata rule, and file format has one owner. Document parsing interprets Markdown and YAML; skill definitions apply name and description rules; ownership interprets installed provenance; installers select destinations and change files. Constructors retain supplied state. Reading, parsing, discovery, and installation have explicit entry points.

Ruby keeps a gem specification with its loaded files. Rust separates the resolved `ContextPackage` from its loaded `PackageContext`. Both apply the same document and installation rules.

Ruby uses the gem name as its package selector. Rust uses the crate name when unique and `crate@version` when multiple versions provide context. These selectors identify providers in commands and installed context directories.

## Documents and Front Matter

`Document.load(path)` and `ContextDocument::load(path)` read the source and delegate to `parse`. The parsed value retains the source path, original Markdown, decoded YAML mapping, and the Markdown parser's front matter node or source boundary.

Both implementations use their Markdown parser's front matter node to read and serialize front matter: Markly in Ruby and `socketry-markdown` in Rust. The document layer decodes and encodes YAML through the node's raw value and classifies context using the nested `metadata.type` field. The skill predicate matches `skill`; all other values follow the ordinary context path. Ordinary guides can carry their own top-level fields. Front matter uses YAML by default or with the explicit `yaml` language hint. Other front matter languages remain opaque.

A skill definition validates its top-level name and description. It preserves an authored name and uses it for the installed directory. When the name is omitted, it derives `<package>-<filename>`. Resource directories follow the source filename. Description validation trims whitespace to measure the value; the authored value is retained.

To generate installed instructions, the definition merges resolved `ecosystem`, `package`, and `version` into the nested metadata mapping and supplies a missing name. The document writes the YAML back to its front matter AST node and asks the Markdown library to serialize that node. It appends the original body using the parser's source boundary. Links, code blocks, spacing, Unicode, and body line endings retain their original bytes.

The portable YAML form uses `---` delimiters. Rust also recognizes the additional front matter forms supported by `socketry-markdown`, such as a leading YAML code fence, and retains their delimiter style. Markly's supported syntax defines the Ruby parsing boundary.

## Discovery and Loading

For each provider, load Markdown documents before descending into subdirectories. Root-level skill declarations identify companion resource directories. Keep those resources opaque, including Markdown-looking assets.

The loaded package stores ordinary definitions and skill definitions in one collection. Listing, showing, and installation use this classification. The main installation operation resolves providers and loads each provider once, then applies the ordinary or skill destination rules to each definition. Ordinary Markdown is written from the loaded source; opaque files are copied directly.

## Installation Flow

The library owns orchestration. Bake tasks translate arguments, call the library, and present installed provider and skill names.

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
