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

Use the same two-turn split as Step 5. Cursor often hides chat text that shares a turn with `AskQuestion`.

**Turn A — chat only (tools forbidden):** print the grouping summary, then `Continue for the grouping confirmation, or say how to split/merge.` Do not call `AskQuestion` / `AskUserQuestion` or any other tool. End the turn.

```
I found N logical commit groups:

Group 1 — [one-line intent] (foo.swift, bar.swift)
Group 2 — [one-line intent] (baz.swift)
```

**Turn B — after the user's next message:** if they already approved or gave a regrouping, follow that. Otherwise invoke `AskQuestion` / `AskUserQuestion` with a short prompt only — do not paste the grouping list into the card.

Question: `Do these groupings look right?`

Options:
- **Yes, looks good** — proceed to draft commits
- **No, reorganize** — ask the user how they'd like them split or merged, then re-confirm from Turn A

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
| 🤖 | add or update ai skills or rules |

## Step 5: Present drafts for approval

Cursor often does **not** render assistant chat that shares a turn with `AskQuestion` / `AskUserQuestion`. The draft must appear in a **tool-free** turn first. The approval card is a short confirm only — never the place the user reads the message.

### Turn A — print the draft (tools forbidden)

Output the full commit message in a fenced `text` block, then one line of instructions. This response must contain **no tool calls**.

```text
✨ add offline sync queue for failed network requests

- add SyncQueue to buffer requests when connectivity is lost
- retry queued requests on network restore using Reachability observer
- persist queue across app launches with UserDefaults

Ensures no data loss during intermittent connectivity without
requiring changes to the existing API call sites.
```

Continue for the approval dialog, or reply Approve / Request changes.

**FORBIDDEN in Turn A:** `AskQuestion`, `AskUserQuestion`, and any other tool. If you are about to call a question tool, you have failed this step — delete the tool call and send the fenced message only. End the turn.

### Turn B — approval card (only after the user replies)

Wait for the user's next message (Continue, OK, or anything else).

- If they already said **Approve** (or unambiguous yes) → skip the card, go to Step 6.
- If they said **Request changes** (or described edits) → revise, then repeat Turn A.
- Otherwise invoke the question tool with a **short** prompt. Do **not** put the commit message in the prompt; it is already in chat.

Cursor `AskQuestion`:
- `title`: `Commit this message?`
- `prompt`: `Commit the message printed above?`

Claude Code `AskUserQuestion`: same short question text.

Options:
- **Approve** — proceed to commit
- **Request changes** — ask what to revise, update draft, re-present from Turn A

Skipped/dismissed/timed-out = NOT approval.

If no question tool is available: Turn A already asked them to reply in chat — wait for that reply.

Multiple commits: each commit gets its own Turn A → wait → Turn B sequence.

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

- **Never `git commit` without explicit user approval.** "Approve" selection or unambiguous affirmative required. Skipped/dismissed/timed-out = NOT approval. Never infer consent.
- **Never call `AskQuestion` / `AskUserQuestion` in the same turn as the commit draft.** Turn A is text-only. The draft must already be visible in chat before Turn B.
- **Never put the commit message in the approval question prompt.** The card is Approve / Request changes only.
- Never `--no-verify` or skip hooks unless user explicitly asks
- Never amend commit already pushed to remote
- If both staged + unstaged changes exist, clarify with user which to include before drafting
