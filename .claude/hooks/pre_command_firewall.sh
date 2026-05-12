#!/bin/bash
# =============================================================================
# Pre-Hook 1: Command Firewall
# Purpose:    Block dangerous bash commands before execution.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (dangerous pattern matched)
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/dangerous_patterns.txt"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
COMMAND="$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d':' -f2- | sed 's/"//g')"

if test "$TOOL_NAME" != "Bash"; then
    exit 0
fi

if echo "$COMMAND" | grep -qE "^[[:space:]]*(echo|#)"; then
    exit 0
fi

if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

while IFS= read -r pattern; do
    case "$pattern" in
        '#'*|'') continue ;;
    esac

    if echo "$COMMAND" | grep -qE "$pattern"; then
        printf "BLOCKED: Command matches dangerous pattern '%s'.\n" "$pattern" >&2
        exit 2
    fi
done < "$CONFIG_FILE"
exit 0
