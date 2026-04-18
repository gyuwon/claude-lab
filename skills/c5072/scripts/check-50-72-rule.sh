#!/bin/bash

# Check if a commit message follows the 50/72 rule
# Usage: ./check-50-72-rule.sh [commit-hash]
# If no commit-hash is provided, checks the latest commit
#
# Width is measured in display columns: full-width characters
# (CJK ideographs, Hangul syllables, Kana, fullwidth forms, etc.)
# count as 2 columns.

if [ $# -eq 0 ]; then
    commit_ref="HEAD"
else
    commit_ref="$1"
fi

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

commit_message=$(git log -1 --pretty=format:"%s%n%b" "$commit_ref")

subject=$(echo "$commit_message" | head -n1)
body=$(echo "$commit_message" | tail -n +2 | sed '/^$/d')

exit_code=0

# Check subject line width (max 50)
subject_width=$(display_width "$subject")
if [ "$subject_width" -gt 50 ]; then
    echo "[FAIL] Subject line too wide: $subject_width columns (max 50)"
    exit_code=1
else
    echo "[PASS] Subject line width: $subject_width columns"
fi

# Check body line widths (max 72)
if [ -n "$body" ]; then
    while IFS= read -r line; do
        line_width=$(display_width "$line")
        if [ "$line_width" -gt 72 ]; then
            echo "[FAIL] Body line too wide: $line_width columns (max 72)"
            echo "Line: $line"
            exit_code=1
        fi
    done <<< "$body"

    if [ $exit_code -eq 0 ]; then
        echo "[PASS] All body lines within 72 columns"
    fi
fi

exit $exit_code
