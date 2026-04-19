---
name: c5072
description: Create a commit with a message following the 50/72 rule from staged changes. Use when the user wants to commit.
allowed-tools: Bash(git *), Bash(bash *)
---

# c5072 — Commit with 50/72 Rule

Create a commit with a clear, descriptive message based on staged changes.

## Syntax

```
/c5072 [topic: <topic>] [short] [add-all|aa] [lang: <language>]
```

**Parameters:**
- `topic` (optional): Area of focus for the commit. If not provided, infer from changes.
- `short` (optional): Create the shortest possible commit message while maintaining clarity.
- `add-all` (alias: `aa`, optional): Run `git add .` to stage all changes before committing.
- `lang` (optional): Language for the commit message (e.g., `English`, `Korean`). Overrides auto-detection.

## Workflow

### 1. Stage Changes (if `add-all` or `aa` flag is provided)

- Run `git add .` to stage all changes

### 2. Pre-Commit Validation

- Run `git diff --staged` to examine ONLY what is already staged
- If no staged changes exist, STOP and inform the user
- If `topic` specified, confirm staged changes match the topic
- Scan for secrets, keys, or sensitive information — abort if found

### 3. Detect Language

- If `lang` parameter is provided, use that language directly
- Otherwise, run `git log -3 --format=%s` to examine the 3 most recent commit messages
- Determine the dominant language used (e.g., English, Korean)
- If the language is unclear or there are no prior commits, default to English
- Write the commit message in the detected (or specified) language

### 4. Draft Message

- Categorize changes (new feature, enhancement, bug fix, refactoring, etc.)
- Write a commit message following the 50/72 rule:
  - Subject line: max 50 characters
  - Body: wrap lines only when they would exceed 72 characters. Do NOT insert line breaks prematurely — fill each line close to 72 characters before wrapping. Short lines (under ~50 characters) followed by another line are a sign of bad wrapping.
- If `short` parameter is provided, create the most concise message possible
- Present the draft message to the user for review
- STOP and wait for user approval before proceeding

### 5. Create Commit

- Execute commit using heredoc format:
  ```
  git commit -m "$(cat <<'EOF'
  Subject line here

  Body here
  EOF
  )"
  ```

### 6. Validate

- Run `${CLAUDE_SKILL_DIR}/scripts/check-50-72-rule.sh` to verify the subject and body widths
- Run `${CLAUDE_SKILL_DIR}/scripts/check-premature-wrap.sh` to verify no premature line breaks in the body
- If either validation fails, use `git commit --amend` with corrected message
- Repeat until both pass (up to 3 attempts)
- If still failing after 3 attempts, STOP and request review

## Important

- Do NOT stage files unless the `add-all` (or `aa`) flag is explicitly provided.
- Do NOT proceed without user approval of the commit message.
