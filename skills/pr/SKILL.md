---
name: pr
description: Create a PR against origin/main. Fetches origin, rebases onto origin/main, lets you pick a commit (HEAD or one from the range), creates a temp branch, pushes, opens a PR, then deletes the temp branch locally.
allowed-tools: Bash(git *), Bash(gh *), Read, Write
---

# pr — Create PR against origin/main

## Syntax

```
/pr [head]
```

**Parameters:**
- `head` (optional): Skip commit selection and use HEAD as the target commit.

## Workflow

### 1. Load prefix

- Read `${CLAUDE_SKILL_DIR}/config.json`
- If the file is missing or `prefix` is absent, ask the user: "브랜치 prefix를 입력해주세요: (예: `alice` → 브랜치명은 `alice/<커밋-제목-slug>` 형태가 됩니다)"
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
- If the output is empty, report "origin/main과 차이가 없습니다." and STOP
- If `head` parameter is provided, skip selection and use HEAD as the target commit
- Number them 1..N (newest → oldest). Entry 1 is HEAD.
  ```
  커밋을 선택하세요 (PR 대상 커밋):
  1) <hash> <subject>   ← HEAD (최신)
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
- Slugify: lowercase, replace spaces and non-alphanumeric chars with `-`, collapse consecutive `-`, strip leading/trailing `-`
- Truncate to 50 characters
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

## Important

- Never push to origin/main directly
- Never force-push
- The temp branch is only ever deleted locally; the remote branch backing the PR stays until the PR is merged/closed
- Do NOT proceed past step 4, step 8 (draft review) without explicit user approval
