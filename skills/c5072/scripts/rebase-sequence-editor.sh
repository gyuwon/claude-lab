#!/bin/bash
# GIT_SEQUENCE_EDITOR hook for c5072 rebase mode.
#
# Rewrites the `git rebase -i` todo file so that commits listed in
# $C5072_REWRITE_LIST are changed from `pick` to `reword`. Also writes
# $C5072_ORDER_FILE: for each reword-marked commit, one line
# "<full-sha>\t<new-msg-path>" in the order the commits will be processed.
#
# The paired $GIT_EDITOR (rebase-commit-editor.sh) reads $C5072_ORDER_FILE
# in order to know which replacement message to apply to each reword.

set -e

todo_file="$1"
rewrite_list="${C5072_REWRITE_LIST:?C5072_REWRITE_LIST not set}"
order_file="${C5072_ORDER_FILE:?C5072_ORDER_FILE not set}"

: > "$order_file"

tmp=$(mktemp)
while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^pick[[:space:]]+([a-f0-9]+)[[:space:]] ]]; then
        short="${BASH_REMATCH[1]}"
        match=$(awk -F'\t' -v s="$short" 'index($1, s) == 1 { print; exit }' "$rewrite_list")
        if [ -n "$match" ]; then
            printf "reword %s\n" "${line#pick }" >> "$tmp"
            printf "%s\n" "$match" >> "$order_file"
            continue
        fi
    fi
    printf "%s\n" "$line" >> "$tmp"
done < "$todo_file"

mv "$tmp" "$todo_file"
