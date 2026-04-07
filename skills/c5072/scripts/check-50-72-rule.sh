#!/bin/bash

# Check if a commit message follows the 50/72 rule
# Usage: ./check-commit-message-rules.sh [commit-hash]
# If no commit-hash is provided, checks the latest commit

if [ $# -eq 0 ]; then
    commit_ref="HEAD"
else
    commit_ref="$1"
fi

commit_message=$(git log -1 --pretty=format:"%s%n%b" "$commit_ref")

subject=$(echo "$commit_message" | head -n1)
body=$(echo "$commit_message" | tail -n +2 | sed '/^$/d')

exit_code=0

# Check subject line length (max 50)
subject_length=${#subject}
if [ $subject_length -gt 50 ]; then
    echo "[FAIL] Subject line too long: $subject_length characters (max 50)"
    exit_code=1
else
    echo "[PASS] Subject line length: $subject_length characters"
fi

# Check body line lengths (max 72)
if [ -n "$body" ]; then
    while IFS= read -r line; do
        line_length=${#line}
        if [ $line_length -gt 72 ]; then
            echo "[FAIL] Body line too long: $line_length characters (max 72)"
            echo "Line: $line"
            exit_code=1
        fi
    done <<< "$body"

    if [ $exit_code -eq 0 ]; then
        echo "[PASS] All body lines within 72 characters"
    fi
fi

exit $exit_code
