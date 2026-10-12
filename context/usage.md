---
metadata:
  type: skill
description: Install and navigate guidance and skills from Ruby gem dependencies, or publish context and skills from a gem using agent-context.
---

# Using and Providing Context

Use `agent-context` to find practical guidance shipped by Ruby gem dependencies and make package guidance available to downstream agents.

## Use Dependency Guidance

Follow the repository's agent instructions and discover installed dependency guidance by listing Markdown files under `.agents/context/GEM/`. Use descriptive filenames to select relevant guides, then read them before changing code that uses the package. For example, `rg --files --hidden --no-ignore .agents/context -g "*.md"` lists the installed Markdown files.

If relevant installed files are missing, run `bundle exec bake agent:context:install` from the consuming project. Run it again after changing dependencies. It installs ordinary context and skills from resolved dependency gems.

To inspect or install guidance from a specific provider:

```bash
bundle exec bake agent:context:list
bundle exec bake agent:context:list --gem async
bundle exec bake agent:context:show --gem async --file thread-safety
bundle exec bake agent:context:install --gem async
```

`show` reads the provider's source file; the `.md` extension is optional. `install --gem NAME` installs both ordinary context and skills from that provider.

Ordinary context is copied to `.agents/context/GEM/`. Repository instructions can direct agents to discover and read relevant guides there.

## Use Dependency Skills

Skills contain procedures for particular tasks and are installed under `.agents/skills/`. Use the matching skill's instructions and resources when its description applies to the work.

```bash
bundle exec bake agent:context:list --gem agent-context
bundle exec bake agent:context:show --gem agent-context --file usage
bundle exec bake agent:context:install
bundle exec bake agent:context:install --gem agent-context
```

The context list marks skill documents with `(skill)`. Show them by their source filename, and install them together with ordinary context. An authored skill name determines its installed directory; a missing name defaults to `<gem>-<filename>`. This document installs as `agent-context-usage/SKILL.md`.

## Keep Sources and Installed Files Separate

The provider's tracked `context/` directory is source content. Installed dependency copies under `.agents/context/` and `.agents/skills/` are generated; edit provider sources and reinstall to update them. Keep repository-only instructions and project-owned skills in the consuming repository.

Installation maintains local Git exclusions for generated context and exact dependency-installed skill directories. Track project-owned skills under `.agents/skills/` and remove blanket `/.agents/` ignore rules when adopting this layout.

Installed `SKILL.md` front matter records `metadata.type: skill` and the resolved `metadata.ecosystem`, `metadata.package`, and `metadata.version`. Ruby refreshes reconcile skills within their selected ecosystem and package scope. A full refresh also removes skills from removed or empty providers. After resolving an installation error, rerun the command to refresh generated files.

## Publish Context and Skills

Put focused Markdown guides in the gem's `context/` directory, using descriptive lowercase filenames. Give each guide a clear heading and introduction, and link related guides together.

To publish a skill, add `context/workflow.md` with metadata describing when to use it:

```markdown
---
metadata:
  type: skill
description: Set up a project using this gem's conventions.
---

# Workflow

Follow the setup instructions.
```

For this example, gem `provider` derives the missing name and installs the document as `.agents/skills/provider-workflow/SKILL.md`. Put companion resources in `context/workflow/`; they are copied alongside the generated instructions. The installer preserves an authored `name` and derives a missing name from the provider package and filename. It retains the description, additional metadata, and original Markdown body, and adds resolved provenance under `metadata`. The top-level resource name `SKILL.md` is reserved for generated instructions.

Include `context/**/*` in the gemspec's packaged files. Installed skill names must use lowercase ASCII letters, digits, and single hyphens, with at most 64 characters. Descriptions must contain 1–1,024 characters and explain the task that should activate the skill.
