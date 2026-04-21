#!/bin/bash
# GIT_EDITOR hook for c5072 rebase mode.
#
# Each invocation (one per `reword` commit produced by the sequence
# editor) reads the next line from $C5072_ORDER_FILE and overwrites the
# message file ($1) with the pre-approved replacement message. A counter
# in $C5072_COUNTER_FILE tracks which line to read next.

set -e

msg_file="$1"
order_file="${C5072_ORDER_FILE:?C5072_ORDER_FILE not set}"
counter_file="${C5072_COUNTER_FILE:?C5072_COUNTER_FILE not set}"

counter=0
[ -f "$counter_file" ] && counter=$(cat "$counter_file")

line_no=$((counter + 1))
line=$(sed -n "${line_no}p" "$order_file")

if [ -z "$line" ]; then
    # Unexpected invocation beyond planned rewrites — leave unchanged.
    exit 0
fi

new_msg=$(printf "%s\n" "$line" | cut -f2)

if [ -n "$new_msg" ] && [ -f "$new_msg" ]; then
    cat "$new_msg" > "$msg_file"
fi

echo "$line_no" > "$counter_file"
