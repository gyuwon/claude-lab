---
name: pr
description: Create a PR against origin/main, or with `respond` analyze PR review comments and either commit fixes (one per comment) or post discussion replies.
allowed-tools: Bash(git *), Bash(gh *), Read, Write, Edit
---

# pr — Create PR or respond to review comments

## Syntax

### Create PR (default)

```
/pr [head|h]
```

**Parameters:**
- `head` (alias: `h`, optional): Skip commit selection and use HEAD as the target commit.

### Respond to review comments

```
/pr respond [<pr>] [--dry]
```

**Parameters:**
- `<pr>` (optional): PR number or URL. Defaults to the current branch's PR (`gh pr view --json number`).
- `--dry` (optional): Print analysis and planned actions only; do not edit, commit, push, or post replies.

## Workflow: Create PR (default)

### 1. Load prefix

- Read `${CLAUDE_SKILL_DIR}/config.json`
- If the file is missing or `prefix` is absent, ask the user: "Please enter a branch prefix: (e.g., `alice` → branch name becomes `alice/<commit-subject-slug>`)"
- Save the answer back to `${CLAUDE_SKILL_DIR}/config.json` as `{"prefix": "<answer>"}`
- Use this value as `<prefix>` throughout

### 2. Fetch origin

- Run `git fetch origin`
- If it fails, report the error and STOP

### 3. Rebase onto origin/main

- Run `git rebase origin/main`
- If it fails (e.g., conflicts), report the error and STOP — do NOT auto-resolve conflicts

### 4. Show commits and ask which to use

- Run `git log origin/main..HEAD --oneline` to list commits in `[origin/main, HEAD]` range (newest first)
- If the output is empty, report "No differences from origin/main." and STOP
- If `head` (or `h`) parameter is provided, skip selection and use HEAD as the target commit
- Number them 1..N (newest → oldest). Entry 1 is HEAD.
  ```
  Select a commit (PR target commit):
  1) <hash> <subject>   ← HEAD (newest)
  2) <hash> <subject>
  ...
  N) <hash> <subject>   ← oldest
  ```
- If there is only one commit, skip selection and proceed with that commit as target
- Otherwise, STOP and wait for the user to pick a number

### 5. Determine target commit

- target = the commit hash at the chosen index (1-based)

### 6. Derive branch name

- Take the subject line of the target commit: `git log -1 --format=%s <target>`
- Slugify to kebab-case using only ASCII lowercase letters, digits, and `-`:
  - Lowercase the subject
  - Replace every character outside `[a-z0-9]` with `-` (this drops Korean and other non-ASCII characters as well as punctuation)
  - Collapse consecutive `-` into a single `-`
  - Strip leading and trailing `-`
- Truncate the slug to 50 characters
- If the resulting slug is empty (e.g., the subject contained no ASCII letters or digits), fall back to the commit's short hash from `git rev-parse --short <target>`
- Branch name = `<prefix>/<slug>`

### 7. Create temp branch and push

- Run `git checkout -b <branch-name> <target>`
- Run `git push origin <branch-name>`
- If push fails, delete the local branch and STOP

### 8. Create PR

- Detect language from `git log -3 --format=%s`: if Korean appears, write in Korean; otherwise English
- Draft PR title (≤70 chars) and body (summary bullet points, NO test plan section)
- Show the draft to the user and STOP for approval
- After approval, run:
  ```
  gh pr create --base main --head <branch-name> --title "<title>" --body "$(cat <<'EOF'
  <body>
  EOF
  )"
  ```
- Print the PR URL

### 9. Return to original branch and clean up

- Run `git checkout -` to return to the previous branch
- Run `git branch -d <branch-name>` to delete the temp branch locally

## Workflow: Respond to review comments

### 1. Identify PR

- If `<pr>` argument is provided, use it (accept number or URL).
- Otherwise, run `gh pr view --json number,headRefName,headRepository` for the current branch.
- If neither resolves a PR, report the error and STOP.

### 2. Checkout PR branch

- Remember the original branch name from `git rev-parse --abbrev-ref HEAD`.
- If not already on the PR head ref, run `git checkout <pr-head-ref>`.
- Run `git pull --ff-only` to sync with the remote PR branch.
- If checkout or pull fails, return to the original branch and STOP.

### 3. Collect unresolved comments

- Line review comments: `gh api repos/{owner}/{repo}/pulls/{n}/comments`
- Issue (general) comments: `gh api repos/{owner}/{repo}/issues/{n}/comments`
- Exclude:
  - Resolved review threads
  - Comments authored by the current user (`gh api user --jq .login`)
  - Threads where the current user has already replied
- If nothing remains, report "No unaddressed comments." and STOP.

### 4. Classify and draft per comment

For each remaining comment:
- Read the file/line context referenced by the comment (if any).
- Classify intent:
  - `[FIX]` — the comment asks for a code change. Draft an edit plan, a commit message following the 50/72 rule, and a reply referencing the upcoming commit.
  - `[REPLY]` — opinion / question / discussion only. Draft a reply.
- Detect language for replies and commit messages from `git log -3 --format=%s` (Korean if any Korean appears, otherwise English).

### 5. Batch approval

- Print all items in a single table:
  ```
  [FIX]   #<id>  <file>:<line>  "<comment excerpt>"
          → commit: <subject>
          → diff:   <summary>
          → reply:  <draft>

  [REPLY] #<id>  <file>:<line>  "<comment excerpt>"
          → reply:  <draft>
  ```
- STOP and wait for explicit approval. If rejected, STOP without making any changes.
- If `--dry` was given, print the table and STOP regardless.

### 6. Execute (after approval)

For each `[FIX]` item, in order:
1. Apply the edit.
2. `git add` only the files touched by this comment.
3. `git commit` with the drafted 50/72 message.
4. Record the resulting commit hash from `git rev-parse HEAD`.

After all `[FIX]` commits:
- Run `git push origin <pr-head-ref>` once.
- If push fails, STOP and report — do not attempt to post replies.

Post replies for every item (both `[FIX]` and `[REPLY]`):
- Line comment thread: `gh api -X POST repos/{owner}/{repo}/pulls/{n}/comments/{id}/replies -f body=<reply>`
- Issue (general) comment: `gh api -X POST repos/{owner}/{repo}/issues/{n}/comments -f body=<reply>` (no native thread; quote or reference the original)
- For `[FIX]` items, include the recorded commit hash in the reply body.

### 7. Return to original branch

- If the PR branch differs from the original, run `git checkout <original-branch>`.

## Important

- Never push to origin/main directly
- Never force-push
- The temp branch (create-PR mode) is only ever deleted locally; the remote branch backing the PR stays until the PR is merged/closed
- Do NOT proceed past step 4 or step 8 (create-PR mode), or step 5 (respond mode) without explicit user approval
- `respond` mode: always skip the current user's own comments and threads they have already replied to
- `respond` mode: `--dry` must not edit, commit, push, or post anything
- `respond` mode: one `[FIX]` commit per comment — never bundle multiple comments into a single commit
