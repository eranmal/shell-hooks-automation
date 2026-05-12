#!/bin/bash
# =============================================================================
# Post-Hook 5: Syntax Checker
# Purpose:    Run appropriate syntax checker based on file extension after edit.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 = syntax OK (or no checker), 1 = syntax error (warn, don't block)
# Supported:  .sh/.bash (bash -n), .py (python3 -m py_compile), .c/.h (gcc -fsyntax-only)
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d':' -f2- | sed 's/"//g')"
SESSION_ID="$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
if test -z "$SESSION_ID"; then
    SESSION_ID="default";
fi
LOG_FILE="$HOOK_DIR/data/session_$SESSION_ID.log"

if test ! -f "$FILE_PATH" || test -z "$FILE_PATH"; then
    exit 0
fi
EXTENSION="${FILE_PATH##*.}"
CHECKER=""
case "$EXTENSION" in
    sh|bash) CHECKER="bash -n \"$FILE_PATH\"" ;;
    py) CHECKER="python3 -m py_compile \"$FILE_PATH\"" ;;
    c|h) CHECKER="gcc -fsyntax-only \"$FILE_PATH\"" ;;
    *)
        printf "No syntax checker for .%s\n" "$EXTENSION" >&2
        exit 0 ;;
esac
ERROR_OUTPUT=$(eval "$CHECKER" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    printf "SYNTAX ERROR in %s:\n" "$FILE_PATH" >&2
    echo "[$LOG_TIME] SYNTAX_ERROR $FILE_PATH ($EXTENSION)" >> "$LOG_FILE"
    exit 1
else
    printf "Syntax OK"
    echo "[$LOG_TIME] SYNTAX_OK $FILE_PATH ($EXTENSION)" >> "$LOG_FILE"
    exit 0
fi
