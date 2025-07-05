# Practical Examples

## Example 1: Installing context from a web framework

```bash
# Install context from Rails
bake agent:context:install --gem rails

# See what Rails provides
bake agent:context:list --gem rails

# View Rails configuration guide
bake agent:context:show --gem rails --file configuration
```

## Example 2: Getting help with a specific gem

```bash
# You're having trouble with the async gem
bake agent:context:list --gem async

# Check the troubleshooting guide
bake agent:context:show --gem async --file troubleshooting

# Install all async context for offline reference
bake agent:context:install --gem async
```

## Example 3: Discovering new gems

```bash
# See what context is available in your project
bake agent:context:list

# Install context from all gems
bake agent:context:install

# Browse the installed context
ls .context/
```

## Example 4: Working with multiple gems

```bash
# Install context from your main dependencies
bake agent:context:install --gem rack
bake agent:context:install --gem sinatra
bake agent:context:install --gem puma

# Now you have context for your web stack
ls .context/
# => rack/ sinatra/ puma/
```

## Example 5: Using context in your workflow

```bash
# Before starting a new feature
bake agent:context:install --gem the-gem-you're-using

# Read the getting started guide
cat .context/the-gem-you're-using/getting-started.md

# Check performance tips
cat .context/the-gem-you're-using/performance.md
```

## Real-world scenario

You're building a Rails API and want to understand how to properly configure Puma:

```bash
# Install Puma context
bake agent:context:install --gem puma

# Read the configuration guide
cat .context/puma/configuration.md

# Check performance recommendations
cat .context/puma/performance.md
```

This gives you practical, gem-specific guidance that might not be in the main documentation.
description:
globs:
alwaysApply: false
---
