#!/bin/bash
# =============================================================================
# Post-Hook 4: Auto-Backup
# Purpose:    After a file edit, create a timestamped backup with rotation.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 always (post-hooks should not block)
# Backups:    data/.backups/<basename>.<timestamp>
# Log:        data/session_<session_id>.log
# =============================================================================

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/hooks.conf"
BACKUP_DIR="$HOOK_DIR/data/.backups"

mkdir -p "$BACKUP_DIR"
INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d':' -f2- | sed 's/"//g')"
SESSION_ID="$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d':' -f2 | sed 's/"//g')"
if test -z "$SESSION_ID"; then
    SESSION_ID="default";
fi

if test ! -f "$FILE_PATH" || test -z "$FILE_PATH"; then
    exit 0
fi

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BASENAME="$(basename "$FILE_PATH")"
BACKUP_NAME="$BASENAME.$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BASENAME"

cp "$FILE_PATH" "$BACKUP_PATH"

FILE_SIZE=$(wc -c < "$FILE_PATH" | tr -d ' ')
LOG_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
LOG_FILE="$HOOK_DIR/data/session_$SESSION_ID.log"

echo "[$LOG_TIME] BACKUP $FILE_PATH -> .backups/$BACKUP_NAME ($FILE_SIZE bytes)" >> "$LOG_FILE"

MAX_BACKUPS=5
if test -f "$CONFIG_FILE"; then
    CONF_VALUE=$(grep "MAX_BACKUPS=" "$CONFIG_FILE" | cut -d'=' -f2)
    if test -n "$CONF_VALUE"; then
        MAX_BACKUPS="$CONF_VALUE"
    fi
fi

BACKUP_COUNT=$(ls -1 "$BACKUP_DIR/$BASENAME."* 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    TO_DELETE=$[BACKUP_COUNT - MAX_BACKUPS]
    OLDEST_BACKUP=$(ls -t "$BACKUP_DIR/$BASENAME."* | tail -n "$TO_DELETE")
    
    for backup in $OLDEST_BACKUP; do
        rm "$backup"
    done
fi
exit 0

