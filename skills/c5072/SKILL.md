---
name: c5072
description: Create a commit with a message following the 50/72 rule from staged changes. Use when the user wants to commit.
allowed-tools: Bash(git *), Bash(bash *)
---

# c5072 — Commit with 50/72 Rule

Create a commit with a clear, descriptive message based on staged changes.

## Syntax

```
/c5072 [topic: <topic>] [short]
```

**Parameters:**
- `topic` (optional): Area of focus for the commit. If not provided, infer from changes.
- `short` (optional): Create the shortest possible commit message while maintaining clarity.

## Workflow

### 1. Pre-Commit Validation

- Run `git diff --staged` to examine ONLY what is already staged
- If no staged changes exist, STOP and inform the user
- If `topic` specified, confirm staged changes match the topic
- Scan for secrets, keys, or sensitive information — abort if found

### 2. Detect Language

- Run `git log -3 --format=%s` to examine the 3 most recent commit messages
- Determine the dominant language used (e.g., English, Korean)
- If the language is unclear or there are no prior commits, default to English
- Write the commit message in the detected language

### 3. Draft Message

- Categorize changes (new feature, enhancement, bug fix, refactoring, etc.)
- Write a commit message following the 50/72 rule:
  - Subject line: max 50 characters
  - Body lines: max 72 characters
- If `short` parameter is provided, create the most concise message possible
- Present the draft message to the user for review
- STOP and wait for user approval before proceeding

### 4. Create Commit

- Execute commit using heredoc format:
  ```
  git commit -m "$(cat <<'EOF'
  Subject line here

  Body here
  EOF
  )"
  ```

### 5. Validate

- Run `${CLAUDE_SKILL_DIR}/scripts/check-50-72-rule.sh` to verify the commit message
- If validation fails, use `git commit --amend` with corrected message
- Repeat until validation passes (up to 3 attempts)
- If still failing after 3 attempts, STOP and request review

## Important

- Do NOT stage files. This command operates ONLY on already staged changes.
- Do NOT proceed without user approval of the commit message.
