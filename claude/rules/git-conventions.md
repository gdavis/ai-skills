# Git Conventions

## Commit Workflow

Never run `git commit` without explicit user approval.

When asked to "draft a commit" or "make a commit":
1. Present the proposed commit message and list of files to be committed
2. Wait for the user to approve, edit, or reject
3. Only run `git commit` after receiving explicit confirmation (e.g., "go ahead", "approved", "commit it")

"Draft" means present for review — do not execute.

## Commit Format

### Summary Line

- Start with a gitmoji that matches the change type (reference: https://gitmoji.dev/)
- All lowercase after the emoji
- Single sentence, no trailing period

### Common Gitmoji

| Emoji | Use |
|-------|-----|
| ✨ | new feature |
| 🐛 | bug fix |
| ♻️ | refactor |
| 🔥 | remove code or files |
| 💄 | UI and style changes |
| ✅ | add or update tests |
| 📝 | documentation |
| ⚡️ | performance |
| 🏗️ | architectural changes |
| 🗃️ | database changes |
| 🔧 | configuration changes |
| 📦️ | packages or compiled files |
| 🩹 | simple non-critical fix |
| 👔 | business logic |

### Description

- Include a bulleted list of changes
- For complex commits, add an explanatory paragraph below the bullet list
- Omit the paragraph when the summary and bullets make the changes self-evident

### Example

```
✨ embed episode metadata into playback status cloud record

- override populateRecord to embed isFavorite and isArchived
- override applyRecord to extract episode flags on import
- add SyncTrigger to detect episode property changes
- add syncTriggersByEntityName to sync configuration

Uses Mistral's custom record mapping to bundle episode state
into the PlaybackStatus CKRecord, matching legacy sync behavior
without schema changes.
```

## Destructive Operations

- NEVER use `git checkout --` to discard working directory changes. This permanently destroys uncommitted work.
- If you need to revert changes you made, use `git stash` to preserve the work first, then confirm with the user before dropping the stash.
- NEVER run any destructive or irreversible git commands (reset, checkout --, clean, etc.) without explicit user approval.
- When the user asks to "undo" or "revert" changes, always confirm which specific changes they want reverted and whether there are any manual changes in those files that should be preserved.
