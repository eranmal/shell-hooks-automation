#!/bin/bash
# =============================================================================
# Post-Hook 6: Session Summary
# Purpose:    Generate a formatted summary from session.log when Claude stops.
# Input:      JSON on stdin: {"session_id":"...","cwd":"...","stop_hook_active":false}
# Exit codes: 0 always
# IMPORTANT:  Checks stop_hook_active first to prevent infinite loops.
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$HOOK_DIR/data"

INPUT="$(cat)"
SESSION_ID="$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
STOP_HOOK_ACTIVE="$(echo "$INPUT" | grep -o '"stop_hook_active":[^,}]*' | cut -d':' -f2 | tr -d ' ')"

if test "$STOP_HOOK_ACTIVE" = "true"; then
    exit 0
fi
if test -z "$SESSION_ID"; then
    SESSION_ID="default";
fi
LOG_FILE="$DATA_DIR/session_$SESSION_ID.log"
if test ! -f "$LOG_FILE"; then
    printf "No session activity recorded.\n"
    exit 0
fi

TOTAL_COMMANDS=$(wc -l < "$LOG_FILE")
BACKUP_COUNT=$(grep -c "BACKUP" "$LOG_FILE")
SYNTAX_OK=$(grep -c "SYNTAX_OK" "$LOG_FILE")
SYNTAX_ERROR=$(grep -c "SYNTAX_ERROR" "$LOG_FILE")
FIRST_COMMANND=$(head -n 1 "$LOG_FILE" | cut -d' ' -f1,2 | tr -d '[]')
LAST_COMMANND=$(tail -n 1 "$LOG_FILE" | cut -d' ' -f1,2 | tr -d '[]')

printf "╔══════════════════════════════════════╗\n"
printf "║        SESSION SUMMARY REPORT        ║\n"
printf "╚══════════════════════════════════════╝\n\n"

printf "Session: %s\n" "$SESSION_ID"
printf "Period:  %s -> %s\n\n" "$FIRST_COMMANND" "$LAST_COMMANND"

printf "── Activity ─────────────────────────\n"
printf "  Total actions:  %d\n" "$TOTAL_ACTIONS"
printf "  Backups made:   %d\n" "$BACKUPS_MADE"
printf "  Syntax checks:  %d\n" "$((SYNTAX_OK + SYNTAX_ERRORS))"
printf "  Syntax errors:  %d\n\n" "$SYNTAX_ERRORS"

printf "── Most Edited Files ────────────────\n"
grep "BACKUP" "$LOG_FILE" | awk '{print $4}' | sort | uniq -c | sort -rn | head -3 | \
    awk '{printf "  %d. %-25s (%s edits)\n", NR, $2, $1}'

printf "\n── File Types ───────────────────────\n"
grep "BACKUP" "$LOG_FILE" | awk '{print $4}' | awk -F. '{print "." $NF}' | sort | uniq -c | \
    awk '{printf "  %-8s files: %d\n", $2, $1}'

exit 0
