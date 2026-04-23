---
name: create-commit
description: Analyze git changes, intelligently group them into logical commits, draft gitmoji-formatted commit messages, and guide the user through approval and committing. Use when the user types /commit, asks to commit changes, wants to create a commit message, or asks to stage and commit work.
---

# Create Commit

Analyze git changes, group logically, draft gitmoji messages, walk user through approval before commit.

## Step 1: Analyze changes

Run these to gather context:

```bash
git status
git diff --stat
git diff --cached --stat
git diff
git diff --cached
```

## Step 2: Group changes into logical commits

Review diffs, group related changes. **One group** if shared intent; **multiple groups** if clearly distinct purposes.

Grouping heuristics:
- Feature + its tests → same group
- Config/dep bumps alongside feature → same group unless unrelated
- Refactor + bug fix → separate groups
- Format/style + logic → separate groups

## Step 3: If multiple groups — confirm with user

Summarize proposed groupings, then use structured question tool to confirm:

- In **Cursor**: use the `AskQuestion` tool
- In **Claude Code**: use the `AskUserQuestion` tool
- If neither available: present numbered options in plain text, wait for reply

Question format:

```
I found N logical commit groups:

Group 1 — [one-line intent] (foo.swift, bar.swift)
Group 2 — [one-line intent] (baz.swift)

Do these groupings look right?
```

Options:
- **Yes, looks good** — proceed to draft commits
- **No, reorganize** — ask user how to split/merge, then re-confirm

Wait for explicit selection.

## Step 4: Draft commit messages

**Tone — keep it concise and direct**
- Describe only what was explicitly changed/fixed; don't restate background, motivation, or context the diff already shows
- No marketing language, no hedging, no recap of how code used to work
- Prefer short verb-led phrases over full sentences when meaning is clear
- If a bullet/paragraph adds nothing beyond the summary, drop it

For each group, write a commit using this format:

**Summary line**
- Start with gitmoji matching change intent (see table)
- All lowercase after the emoji
- Single sentence, no trailing period

**Body**
- Bulleted list of specific changes — one line each, no filler
- Footer paragraph **only** when bullets don't sufficiently explain (e.g. "why" is non-obvious, or constraint/trade-off worth noting); otherwise omit

### Gitmoji Reference

| Emoji | Intent |
|-------|--------|
| ✨ | new feature |
| 🐛 | bug fix |
| 🚑️ | critical hotfix |
| ♻️ | refactor |
| 🔥 | remove code or files |
| 💄 | UI and style changes |
| ✅ | add or update tests |
| 📝 | documentation |
| ⚡️ | performance improvement |
| 🏗️ | architectural changes |
| 🗃️ | database changes |
| 🔧 | configuration changes |
| 📦️ | packages or compiled files |
| 🩹 | simple non-critical fix |
| 👔 | business logic |
| 🎨 | improve code structure / format |
| 🚚 | move or rename files |
| 💥 | breaking changes |
| 🔀 | merge branches |
| 🌐 | internationalization / localization |
| 🔒️ | fix security or privacy issues |
| ⬆️ | upgrade dependencies |
| ⬇️ | downgrade dependencies |
| 👷 | CI build system or AI tools |
| 🚨 | fix compiler / linter warnings |
| 💡 | add or update source comments |
| 🏷️ | add or update types |
| 🌱 | add or update seed files |
| 🧪 | add a failing test |
| 🗑️ | deprecate code that needs cleanup |
| ⚰️ | remove dead code |
| 🔐 | add or update secrets |
| 🩺 | add or update healthcheck |
| 🚩 | add / update / remove feature flags |
| 🛂 | authorization, roles, and permissions |
| 🧵 | multithreading or concurrency |
| 🦺 | add or update validation |

## Step 5: Present drafts for approval

For each commit, output drafted message to chat as fenced code block, then immediately invoke structured question tool:

- In **Cursor**: use the `AskQuestion` tool
- In **Claude Code**: use the `AskUserQuestion` tool
- If neither available: present numbered options in plain text, wait for reply

**Don't put commit message content inside the question prompt.** Prompt contains only question text + options.

Example — output to chat first:

```
✨ add offline sync queue for failed network requests

- add SyncQueue to buffer requests when connectivity is lost
- retry queued requests on network restore using Reachability observer
- persist queue across app launches with UserDefaults

Ensures no data loss during intermittent connectivity without
requiring changes to the existing API call sites.
```

Then immediately invoke the question tool:

Question: `Commit this message?`

Options:
- **Approve** — proceed to commit
- **Request changes** — ask user what to revise, update draft, re-present for approval

For multiple commits, present each draft with its own approval question in sequence. Don't batch into single question.

## Step 6: Commit on approval

Once approved, commit via heredoc to preserve multi-line formatting:

```bash
git commit -m "$(cat <<'EOF'
✨ add offline sync queue for failed network requests

- add SyncQueue to buffer requests when connectivity is lost
- retry queued requests on network restore using Reachability observer
- persist queue across app launches with UserDefaults

Ensures no data loss during intermittent connectivity without
requiring changes to the existing API call sites.
EOF
)"
```

For multiple commits, ask user how to stage each group (by file, by hunk, etc.) before committing in sequence.

## Hard rules

- **Never run `git commit` without explicit user approval**
- Never pass `--no-verify` or skip hooks unless user explicitly asks
- Never amend a commit already pushed to remote
- If both staged + unstaged changes exist, clarify with user which to include before drafting
