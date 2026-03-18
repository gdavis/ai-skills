# AI Skills

A collection of AI instructions, rules, and skills for Claude Code and Cursor.

## Repository Structure

```
claude/
  CLAUDE.md               # global Claude Code instructions
  rules/
    {name}.md             # Claude Code rule files
cursor/
  rules/
    {name}.mdc            # Cursor rule with YAML front-matter
  skills/
    {name}/
      SKILL.md            # skill definition with YAML front-matter
install.sh                # installer script
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

| Source | Destination |
|--------|-------------|
| `claude/CLAUDE.md` | `{target}/.claude/CLAUDE.md` |
| `claude/rules/*.md` | `{target}/.claude/rules/` |
| `cursor/rules/*.mdc` | `{target}/.cursor/rules/` |
| `cursor/skills/*/SKILL.md` | `{target}/.cursor/skills/` |

Where `{target}` is `~/` for user-global installs, or `{project}/` for project installs.

## Adding New Items

**Claude rule** — create `claude/rules/{name}.md`:

```markdown
# My Rule

Rule content here...
```

**Cursor skill** — create `cursor/skills/{name}/SKILL.md` with front-matter:

```markdown
---
name: my-skill
description: What this skill does
---

# My Skill
...
```

**Cursor rule** — create `cursor/rules/{name}.mdc` with front-matter:

```markdown
---
description: What this rule enforces
alwaysApply: true
---

# My Rule
...
```
