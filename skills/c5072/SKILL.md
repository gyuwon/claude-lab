---
name: c5072
description: Create a commit with a message following the 50/72 rule from staged changes, or rewrite commit messages in a range to comply. Use when the user wants to commit, or to retrofit the rule onto prior history.
allowed-tools: Bash(git *), Bash(bash *)
---

# c5072 — Commit with 50/72 Rule

Two modes:

- **Commit mode (default):** create a new commit from staged changes.
- **Rebase mode:** rewrite commit messages in `<base-ref>..HEAD` to comply with the rule, preserving content.

## Syntax

Commit mode:

```
/c5072 [topic: <topic>] [short] [add-all|aa] [lang: <language>]
```

Rebase mode:

```
/c5072 rebase <base-ref> [lang: <language>]
```

**Commit mode parameters:**
- `topic` (optional): Area of focus for the commit. If not provided, infer from changes.
- `short` (optional): Create the shortest possible commit message while maintaining clarity.
- `add-all` (alias: `aa`, optional): Run `git add .` to stage all changes before committing.
- `lang` (optional): Language for the commit message (e.g., `English`, `Korean`). Overrides auto-detection.

**Rebase mode parameters:**
- `base-ref` (required): Ancestor ref. Commits in `<base-ref>..HEAD` are candidates for rewriting.
- `lang` (optional): Language for rewritten messages. Overrides auto-detection.

## Commit Mode Workflow

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

## Rebase Mode Workflow

### 1. Preflight

- Run `git status --porcelain`. If output is non-empty, STOP (working tree must be clean).
- Run `git merge-base --is-ancestor <base-ref> HEAD`. If non-zero exit, STOP.
- Run `git log --format=%H <base-ref>..HEAD`. If empty, STOP.
- Run `git log --format=%P <base-ref>..HEAD`. If any line has two or more fields, STOP (merge commits present; linear history only).
- If `.git/rebase-merge` or `.git/rebase-apply` exists, STOP (another rebase already in progress).
- Save backup ref and show the name to the user:
  ```
  BACKUP=refs/c5072/backup-$(date +%Y%m%d-%H%M%S)
  git update-ref "$BACKUP" HEAD
  ```
- Warn (but do not stop) if any target SHA appears in `git branch -r --contains <sha>` — rewriting will require a force-push.

### 2. Identify Failing Commits

- Create working dir: `WORKDIR=$(mktemp -d) && mkdir "$WORKDIR/msgs"`
- For each SHA from `git log --format=%H <base-ref>..HEAD --reverse`:
  - Run `bash ${CLAUDE_SKILL_DIR}/scripts/check-50-72-rule.sh <sha>`
  - Run `bash ${CLAUDE_SKILL_DIR}/scripts/check-premature-wrap.sh <sha>`
  - If either fails, add the SHA and failure reason to the rewrite list.
- If the rewrite list is empty, report "No rewrites needed" and STOP.

### 3. Detect Language

- If `lang` parameter is provided, use it.
- Otherwise sample `git log -3 --format=%s`.
- Default English if unclear.

### 4. Draft Rewrites

- For each failing SHA:
  - Read original message: `git log -1 --format=%B <sha>`.
  - Draft a compliant replacement that preserves the original meaning.
  - Write the replacement to `$WORKDIR/msgs/<sha>.txt`.
  - Append `<sha>\t$WORKDIR/msgs/<sha>.txt` to `$WORKDIR/rewrites.txt` (tab-separated, full SHA).

### 5. Present and Approve

Show every rewrite in a single review:

```
[i/N] <short-sha> — <reason>
  Before:
    <old message>
  After:
    <new message>
```

STOP and wait for approval. Accept only "all / cancel" — no partial apply in v1.

### 6. Execute Rebase

Run (substituting real paths, with `$WORKDIR` and `${CLAUDE_SKILL_DIR}` expanded by the outer shell):

```bash
C5072_REWRITE_LIST="$WORKDIR/rewrites.txt" \
C5072_ORDER_FILE="$WORKDIR/order.txt" \
C5072_COUNTER_FILE="$WORKDIR/counter.txt" \
GIT_SEQUENCE_EDITOR="bash ${CLAUDE_SKILL_DIR}/scripts/rebase-sequence-editor.sh" \
GIT_EDITOR="bash ${CLAUDE_SKILL_DIR}/scripts/rebase-commit-editor.sh" \
git rebase -i <base-ref>
```

If the rebase exits non-zero:
- Run `git rebase --abort` (ignore errors if no rebase is active).
- Run `git reset --hard <backup-ref>`.
- STOP and report.

### 7. Verify

- For each SHA from `git log --format=%H <base-ref>..HEAD --reverse`, re-run both check scripts.
- If any commit still fails: `git reset --hard <backup-ref>` and STOP.
- On success, print:
  - The backup ref name (kept for manual recovery).
  - The new `<base-ref>..HEAD` commit list.

## Important

- Do NOT stage files in commit mode unless `add-all` (or `aa`) is provided.
- Do NOT proceed in either mode without user approval of the drafted message(s).
- Rebase mode requires a clean working tree and a linear target range (no merge commits).
- Rebase mode saves a backup ref before rewriting; recover via `git reset --hard <backup-ref>` if anything goes wrong.
- Rebase mode rewrites history — if the target range has already been pushed, a subsequent force-push will be required (not performed by this skill).
