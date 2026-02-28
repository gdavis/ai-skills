---
name: create-commit
description: Analyze git changes, intelligently group them into logical commits, draft gitmoji-formatted commit messages, and guide the user through approval and committing. Use when the user types /commit, asks to commit changes, wants to create a commit message, or asks to stage and commit work.
---

# Create Commit

Analyze git changes, group them logically, draft gitmoji commit messages, and walk the user through approval before committing.

## Step 1: Analyze changes

Run these commands to gather full context:

```bash
git status
git diff --stat
git diff --cached --stat
git diff
git diff --cached
```

## Step 2: Group changes into logical commits

Review the diffs and group related changes. Use **one group** if everything shares a single intent; use **multiple groups** if changes serve clearly distinct purposes.

Grouping heuristics:
- Changes to a feature and its tests → same group
- Config or dependency bumps alongside feature code → same group unless unrelated
- Refactor mixed with a bug fix → separate groups
- Formatting/style changes alongside logic changes → separate group

## Step 3: If multiple groups — confirm with user

Present a summary of proposed groupings, then use the structured question tool to confirm:

- In **Cursor**: use the `AskQuestion` tool
- In **Claude Code**: use the `AskUserQuestion` tool
- If neither is available: present numbered options in plain text and wait for a reply

Question format:

```
I found N logical commit groups:

Group 1 — [one-line intent] (foo.swift, bar.swift)
Group 2 — [one-line intent] (baz.swift)

Do these groupings look right?
```

Options:
- **Yes, looks good** — proceed to draft commits
- **No, reorganize** — ask the user how they'd like them split or merged, then re-confirm

Wait for explicit selection before proceeding.

## Step 4: Draft commit messages

For each group, write a commit using this format:

**Summary line**
- Start with a gitmoji matching the change intent (see table below)
- All lowercase after the emoji
- Single sentence, no trailing period

**Body**
- Bulleted list of specific changes
- Optional explanatory paragraph for complex commits; omit when summary + bullets are self-evident

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

For each commit, output the drafted message to the chat log as a fenced code block, then immediately invoke the structured question tool:

- In **Cursor**: use the `AskQuestion` tool
- In **Claude Code**: use the `AskUserQuestion` tool
- If neither is available: present numbered options in plain text and wait for a reply

**Do not include the commit message content inside the question prompt.** The question prompt contains only the question text and options.

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
- **Request changes** — ask the user what to revise, update the draft, and re-present for approval

For multiple commits, present each draft individually with its own approval question, in sequence. Do not batch all commits into a single question.

## Step 6: Commit on approval

Once approved, commit using a heredoc to preserve multi-line formatting:

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

For multiple commits, ask the user how to stage each group (by file, by hunk, etc.) before committing each one in sequence.

## Hard rules

- **Never run `git commit` without explicit user approval**
- Never pass `--no-verify` or skip hooks unless the user explicitly asks
- Never amend a commit that has already been pushed to remote
- If both staged and unstaged changes exist, clarify with the user which to include before drafting
