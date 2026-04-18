#!/bin/bash

# Check if a commit message body contains premature line breaks.
# A line is "prematurely wrapped" when the first word of the next
# line could have been joined to the current line without exceeding
# 72 display columns, and structural context does not forbid that
# join (paragraph boundary, list item, trailer, code block, etc.).
#
# Usage: ./check-premature-wrap.sh [commit-hash]
# If no commit-hash is provided, checks the latest commit.
#
# Width is measured in display columns; full-width characters
# (CJK ideographs, Hangul syllables, Kana, fullwidth forms, etc.)
# count as 2 columns.

if [ $# -eq 0 ]; then
    commit_ref="HEAD"
else
    commit_ref="$1"
fi

MAX_WIDTH=72

display_width() {
    perl -CA -e '
        my $s = $ARGV[0];
        my $w = 0;
        for my $c (split //, $s) {
            my $o = ord($c);
            if (($o >= 0x1100 && $o <= 0x115F) ||
                ($o == 0x2329 || $o == 0x232A) ||
                ($o >= 0x2E80 && $o <= 0x303E) ||
                ($o >= 0x3041 && $o <= 0x33FF) ||
                ($o >= 0x3400 && $o <= 0x4DBF) ||
                ($o >= 0x4E00 && $o <= 0x9FFF) ||
                ($o >= 0xA000 && $o <= 0xA4CF) ||
                ($o >= 0xAC00 && $o <= 0xD7A3) ||
                ($o >= 0xF900 && $o <= 0xFAFF) ||
                ($o >= 0xFE30 && $o <= 0xFE4F) ||
                ($o >= 0xFF00 && $o <= 0xFF60) ||
                ($o >= 0xFFE0 && $o <= 0xFFE6)) {
                $w += 2;
            } else {
                $w += 1;
            }
        }
        print $w;
    ' -- "$1"
}

# Return 0 if the line is a structural element that should not be
# merged with its neighbor (list item, trailer, heading, quote,
# indented/code line). Return 1 otherwise.
is_structural() {
    local line="$1"
    # Bullet list: - item, * item, + item
    if [[ "$line" =~ ^[[:space:]]*[-*+][[:space:]]+ ]]; then
        return 0
    fi
    # Numbered list: 1. item, 1) item
    if [[ "$line" =~ ^[[:space:]]*[0-9]+[.\)][[:space:]]+ ]]; then
        return 0
    fi
    # Trailer: Key: value  (e.g. Co-authored-by:, Signed-off-by:, Fixes:)
    if [[ "$line" =~ ^[A-Z][A-Za-z0-9-]*:[[:space:]] ]]; then
        return 0
    fi
    # Indented (4+ spaces or tab) — treated as code / preformatted
    if [[ "$line" =~ ^([[:space:]]{4,}|$'\t') ]]; then
        return 0
    fi
    # Heading
    if [[ "$line" =~ ^#+[[:space:]] ]]; then
        return 0
    fi
    # Blockquote
    if [[ "$line" =~ ^\>[[:space:]]? ]]; then
        return 0
    fi
    return 1
}

body=$(git log -1 --pretty=format:"%b" "$commit_ref")

if [ -z "$body" ]; then
    echo "[SKIP] No body to check"
    exit 0
fi

lines=()
while IFS= read -r line; do
    lines+=("$line")
done <<< "$body"

exit_code=0
warnings=0
in_code_fence=0

for ((i = 0; i < ${#lines[@]}; i++)); do
    line="${lines[$i]}"

    # Toggle code fence on ```
    if [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
        in_code_fence=$((1 - in_code_fence))
        continue
    fi
    if [ $in_code_fence -eq 1 ]; then
        continue
    fi

    next_idx=$((i + 1))
    if [ $next_idx -ge ${#lines[@]} ]; then
        continue
    fi
    next_line="${lines[$next_idx]}"

    # Paragraph boundary: current or next is blank
    if [ -z "$line" ] || [ -z "$next_line" ]; then
        continue
    fi

    # Next line opens a code fence — don't try to merge
    if [[ "$next_line" =~ ^[[:space:]]*\`\`\` ]]; then
        continue
    fi

    # Skip structural lines (either side)
    if is_structural "$line"; then
        continue
    fi
    if is_structural "$next_line"; then
        continue
    fi

    # First token of next line (handles leading whitespace)
    read -r first_word _ <<< "$next_line"
    if [ -z "$first_word" ]; then
        continue
    fi

    cur_width=$(display_width "$line")
    first_word_width=$(display_width "$first_word")
    joined_width=$((cur_width + 1 + first_word_width))

    if [ "$joined_width" -le "$MAX_WIDTH" ]; then
        # Body line numbers are 1-based; body starts two lines below
        # the commit subject in the final message, but we report the
        # index within the body for clarity.
        body_line=$((i + 1))
        echo "[FAIL] Premature line break at body line $body_line"
        echo "  Line: $line ($cur_width cols)"
        echo "  Next: $next_line"
        echo "  Joining '$first_word' would yield $joined_width cols (<= $MAX_WIDTH)"
        exit_code=1
        warnings=$((warnings + 1))
    fi
done

if [ $exit_code -eq 0 ]; then
    echo "[PASS] No premature line breaks detected"
else
    echo ""
    echo "Total premature line breaks: $warnings"
fi

exit $exit_code
