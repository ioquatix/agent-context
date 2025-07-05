# Adding Context to Your Gem

## How to provide context in your gem

### 1. Create a `context/` directory

In your gem's root directory, create a `context/` folder:

```
your-gem/
├── context/
│   ├── getting-started.md
│   ├── configuration.md
│   └── troubleshooting.md
├── lib/
└── your-gem.gemspec
```

### 2. Add context files

Create files with helpful information. Common types include:

- **getting-started.md** - Quick start guide
- **configuration.md** - Configuration options and examples
- **troubleshooting.md** - Common issues and solutions
- **migration.md** - Migration guides between versions
- **performance.md** - Performance tips and best practices
- **security.md** - Security considerations

### 3. Document your context

Add a section to your gem's README:

```markdown
## Context

This gem provides additional context files that can be installed using `agent-context`:

```bash
bake agent:context:install --gem your-gem-name
```

Available context files:
- `getting-started.md` - Quick start guide
- `configuration.md` - Configuration options
```

### 4. File format

Context files can be in any format, but `.md` and `.md` are commonly used for documentation. The content should be:

- **Practical** - Include real examples
- **Focused** - One topic per file
- **Clear** - Easy to understand and follow
- **Actionable** - Provide specific guidance

## Example context file

```markdown
# Configuration Guide

## Basic Setup

Add to your Gemfile:
```ruby
gem "your-gem"
```

## Configuration Options

```ruby
YourGem.configure do |config|
  config.timeout = 30
  config.retries = 3
end
```

## Environment Variables

- `YOUR_GEM_TIMEOUT` - Connection timeout in seconds
- `YOUR_GEM_RETRIES` - Number of retry attempts


- `YOUR_GEM_TIMEOUT` - Connection timeout in seconds
- `YOUR_GEM_RETRIES` - Number of retry attempts
# Adding Context to Your Gem

## How to provide context in your gem

### 1. Create a `context/` directory

In your gem's root directory, create a `context/` folder:

```
your-gem/
├── context/
│   ├── getting-started.md
│   ├── configuration.md
│   └── troubleshooting.md
├── lib/
└── your-gem.gemspec
```

### 2. Add context files

Create files with helpful information. Common types include:

- **getting-started.md** - Quick start guide
- **configuration.md** - Configuration options and examples
- **troubleshooting.md** - Common issues and solutions
- **migration.md** - Migration guides between versions
- **performance.md** - Performance tips and best practices
- **security.md** - Security considerations

### 3. Document your context

Add a section to your gem's README:

```markdown
## Context

This gem provides additional context files that can be installed using `bake agent:context:install`.
```

### 4. File format

Context files can be in any format, but `.md` and `.md` are commonly used for documentation. The content should be:

- **Practical** - Include real examples
- **Focused** - One topic per file
- **Clear** - Easy to understand and follow
- **Actionable** - Provide specific guidance

## Example context file

```markdown
# Configuration Guide

## Basic Setup

Add to your Gemfile:
```ruby
gem "your-gem"
```

## Configuration Options

```ruby
YourGem.configure do |config|
  config.timeout = 30
  config.retries = 3
end
```

## Environment Variables

- `YOUR_GEM_TIMEOUT` - Connection timeout in seconds
- `YOUR_GEM_RETRIES` - Number of retry attempts


- `YOUR_GEM_TIMEOUT` - Connection timeout in seconds
- `YOUR_GEM_RETRIES` - Number of retry attempts
