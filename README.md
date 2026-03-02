# AI Skills

A collection of AI skills for Claude Code and rules for Cursor.

## Repository Structure

```
skills/
  {name}/
    SKILL.md          # skill definition with YAML front-matter
rules/
  {name}.mdc          # Cursor rule with YAML front-matter
install.sh            # installer script
```

## Installation

```bash
# interactive — prompts for target and item selection
./install.sh

# install globally for the current user
./install.sh --user

# install into a specific project
./install.sh --project /path/to/project
```

## CLI Flags

| Flag | Description |
|------|-------------|
| `--user` | Install to user-global directories (`~/.claude`, `~/.cursor`) |
| `--project <path>` | Install to a specific project directory |
| `--force` | Overwrite conflicts without prompting |
| `--link` | Create symlinks instead of copies (useful during development) |
| `--dry-run` | Show what would be done without making changes |
| `-h`, `--help` | Show help message |

## What Gets Installed Where

| Content | Claude Code | Cursor |
|---------|-------------|--------|
| Skills (`skills/*/SKILL.md`) | `{target}/skills/{name}/SKILL.md` | `{target}/skills/{name}/SKILL.md` |
| Rules (`rules/*.mdc`) | — | `{target}/rules/{name}.mdc` |

Where `{target}` is `~/.claude` / `~/.cursor` for user-global installs, or `{project}/.claude` / `{project}/.cursor` for project installs.

## Adding New Skills or Rules

**Skill** — create `skills/{name}/SKILL.md` with front-matter:

```markdown
---
name: my-skill
description: What this skill does
---

# My Skill
...
```

**Rule** — create `rules/{name}.mdc` with front-matter:

```markdown
---
description: What this rule enforces
alwaysApply: true
---

# My Rule
...
```
