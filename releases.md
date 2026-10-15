# Releases

## Unreleased

- Sign releases with the Socketry certificate and publish through reviewed GitHub release PRs.

- Resolve context source filenames before installed skill names and show authored content consistently.

- Install unfamiliar context types as ordinary guidance so providers can introduce new types.
- Store resolved skill provenance in `SKILL.md` front matter under `metadata`, with `metadata.type: skill` declaring skills.
- Preserve authored names, descriptions, additional metadata, and the original Markdown body using native front matter AST nodes.
- Share loaded documents between context and skill installation, and use direct writes with rerunnable progress.
- Discover dependency guidance through installed Markdown files and the list/show commands. Remove generated indexes and the `agent:context:index` task.

## v0.3.0

  - Rename `agent.md` -\> `agents.md`.

## v0.2.0

  - Don't limit description length.
