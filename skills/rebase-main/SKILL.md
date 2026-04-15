---
name: rebase-main
description: Fetch origin and rebase the current branch onto origin/main. Use when the user wants to sync with the latest main.
allowed-tools: Bash(git *)
---

# rebase-main — Rebase onto origin/main

Fetch from origin and rebase the current branch onto `origin/main`.

## Syntax

```
/rebase-main
```

No parameters.

## Workflow

### 1. Fetch origin

- Run `git fetch origin`
- If it fails, report the error and STOP

### 2. Rebase onto origin/main

- Run `git rebase origin/main`
- If it fails (e.g., conflicts), report the error and STOP — do NOT auto-resolve conflicts

### 3. Report result

- Print the current branch name and the new HEAD commit hash

## Important

- Never force-push or modify remote state
- Do NOT auto-resolve rebase conflicts — stop and let the user handle them
