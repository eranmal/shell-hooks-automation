#!/bin/bash
# =============================================================================
# Pre-Hook 3: Commit Message Validator
# Purpose:    Validate git commit messages follow conventional commit format.
#             Suggests a prefix if one is missing based on staged diff heuristics.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (invalid commit message)
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/commit_prefixes.txt"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
COMMAND="$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d':' -f2- | sed 's/"//g')"

if test "$TOOL_NAME" != "Bash"; then
    exit 0
fi
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

if [[ ! "$COMMAND" =~ "git commit" ]]; then
    exit 0
fi
REGEX="[[:space:]](-m|-am|-a[[:space:]]+-m)[[:space:]]+['\"]([^'\"]+)['\"]"
if [[ "$COMMAND" =~ $REGEX ]]; then
    MSG="${BASH_REMATCH[2]}"
else
    exit 0
fi
VALID_PREFIXES=$(paste -sd '|' "$CONFIG_FILE")
PREFIX_PATTERN="^($VALID_PREFIXES): "

if [[ ! "$MSG" =~ $PREFIX_PATTERN ]]; then
    STAGED_CHANGES=$(git diff --cached --name-status)
    STAT_INFO=$(git diff --cached --shortstat)
    SUGGESTED_PREFIX="feat"
    if echo "$STAGED_CHANGES" | grep -qiE "test|spec"; then
        SUGGESTED_PREFIX="test"
    elif echo "$STAGED_CHANGES" | grep -qiE "README|\.md"; then
        SUGGESTED_PREFIX="docs"
    else
        ADDED=$(echo "$STAT_INFO" | grep -o "[0-9]* insertion" | cut -d' ' -f1)
        DELETIONS=$(echo "$STAT_INFO" | grep -o "[0-9]* deletion" | cut -d' ' -f1)
        if [[ $DELETIONS -gt $ADDED ]]; then
            SUGGESTED_PREFIX="refactor"
        fi
    fi
    printf "Missing commit prefix. Based on your changes, try: '%s: %s'\n" "$SUGGESTED_PREFIX" "$MSG" >&2
    printf "Valid prefixes: feat, fix, docs, style, refactor, test, chore\n" >&2
    exit 2
fi

MSG_LEN=${#MSG}
if [[ $MSG_LEN -gt 72 || $MSG_LEN -lt 10 ]]; then
    exit 2
fi
if [[ "$MSG" == *. ]]; then
    exit 2
fi
exit 0
