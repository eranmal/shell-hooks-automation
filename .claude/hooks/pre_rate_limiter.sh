#!/bin/bash
# =============================================================================
# Pre-Hook 2: Rate Limiter
# Purpose:    Track command count per session, block after exceeding limit.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},"session_id":"..."}
# Exit codes: 0 = allow (possibly with warning), 2 = blocked (limit exceeded)
# State file: data/.command_count — format per line: session_id|total|type1:N,type2:N,...
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/hooks.conf"
STATE_FILE="$HOOK_DIR/data/.command_count"
RESET_FILE="$HOOK_DIR/data/.reset_commands"

mkdir -p "$HOOK_DIR/data"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
SESSION_ID="$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
if test -z "$SESSION_ID"; then
    SESSION_ID="default";
fi
COMMAND="$(echo "$INPUT" | grep -o '"command":"[^"]*"' | cut -d':' -f2- | sed 's/"//g')"

CMD_TYPE="$(echo "$COMMAND" | cut -d' ' -f1)"

if test -f "$RESET_FILE"; then
    if test -f "$STATE_FILE"; then
        grep -v "^$SESSION_ID|" "$STATE_FILE" > "$STATE_FILE.tmp"
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi
    rm "$RESET_FILE"
    exit 0
fi

if test "$TOOL_NAME" != "Bash"; then
    exit 0
fi

if test -f "$CONFIG_FILE"; then
    MAX_COMMANDS=$(grep "MAX_COMMANDS=" "$CONFIG_FILE" | cut -d'=' -f2)
    WARNING_THRESHOLD=$(grep "WARNING_THRESHOLD=" "$CONFIG_FILE" | cut -d'=' -f2)
fi


TOTAL=0
TYPE_COUNTS=""
if test -f "$STATE_FILE"; then
    LINE="$(grep "^$SESSION_ID|" "$STATE_FILE")"
    if test -n "$LINE"; then
        TOTAL="$(echo "$LINE" | cut -d'|' -f2)"
        TYPE_COUNTS="$(echo "$LINE" | cut -d'|' -f3)"
    fi
fi

TOTAL=$((TOTAL + 1))
if echo "$TYPE_COUNTS" | grep -qE "$CMD_TYPE:"; then
  OLD_TYPE_COUNT="$(echo "$TYPE_COUNTS" | grep -o "$CMD_TYPE:[0-9]*" | cut -d':' -f2)"
  NEW_TYPE_COUNT=$((OLD_TYPE_COUNT + 1))
  TYPE_COUNTS="$(echo "$TYPE_COUNTS" | sed "s/$CMD_TYPE:$OLD_TYPE_COUNT/$CMD_TYPE:$NEW_TYPE_COUNT/")"
else
  if test -z "$TYPE_COUNTS"; then
    TYPE_COUNTS="$CMD_TYPE:1"
  else
    TYPE_COUNTS="$TYPE_COUNTS,$CMD_TYPE:1"
  fi
fi

if test -f "$STATE_FILE"; then
    grep -v "^$SESSION_ID|" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
fi
echo "$SESSION_ID|$TOTAL|$TYPE_COUNTS" >> "$STATE_FILE"

if test "$TOTAL" -gt "$MAX_COMMANDS"; then
    printf "BLOCKED: Session '%s' exceeded max command limit (%d > %d).\n" "$SESSION_ID" "$TOTAL" "$MAX_COMMANDS" >&2
    exit 2
elif test "$TOTAL" -gt "$WARNING_THRESHOLD"; then
    printf "WARNING: Session '%s' approaching command limit (%d/%d).\n" "$SESSION_ID" "$TOTAL" "$MAX_COMMANDS" >&2
fi
exit 0

