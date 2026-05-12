#!/bin/bash
# =============================================================================
# Hook Runner
# Purpose:    Standalone simulator of Claude Code's hook execution for testing.
#             Reads hooks_config.txt, matches event+tool, runs hooks in order.
# Usage:      echo '<json>' | ./hook_runner.sh <event_type> <tool_name>
# Examples:
#   echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"s1"}' \
#       | ./hook_runner.sh PreToolUse Bash
#   echo '{"tool_name":"Edit","tool_input":{"file_path":"main.c"},"session_id":"s1"}' \
#       | ./hook_runner.sh PostToolUse Edit
# =============================================================================

# ── Colour codes ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$RUNNER_DIR/hooks_config.txt"

# ── Argument validation ────────────────────────────────────────────────────────
if [ -z "$1" ] || [ -z "$2" ]; then
    printf '%bUsage:%b echo '"'"'<json>'"'"' | %s <event_type> <tool_name>\n' "$BOLD" "$RESET" "$0"
    printf '\n'
    printf 'event_type examples: PreToolUse, PostToolUse, Stop\n'
    printf 'tool_name  examples: Bash, Edit, Write, MultiEdit, *\n'
    printf '\n'
    printf 'Config file: %s\n' "$CONFIG_FILE"
    exit 1
fi

EVENT_TYPE="$1"
TOOL_NAME="$2"

# ── Validate config file ───────────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    printf '%bERROR:%b Config file not found: %s\n' "$RED" "$RESET" "$CONFIG_FILE" >&2
    exit 1
fi

# ── Read stdin into temp file (hooks need to re-read it) ──────────────────────
TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT
cat > "$TEMP_FILE"

printf '%b─── Hook Runner (%s / %s) ───%b\n' "$BOLD" "$EVENT_TYPE" "$TOOL_NAME" "$RESET"
printf '\n'

# ── Statistics ────────────────────────────────────────────────────────────────
MATCHED=0
PASSED=0
BLOCKED=0
WARNINGS=0
FINAL_EXIT=0

while read -r line; do
    # 1. Skip comment and empty lines
    if echo "$line" | grep -q '^#' || [ -z "$line" ]; then
        continue
    fi
    
    # 2. Split line into fields 
    CONF_EVENT=$(echo "$line" | cut -d':' -f1)
    CONF_MATCHER=$(echo "$line" | cut -d':' -f2)
    CONF_SCRIPT=$(echo "$line" | cut -d':' -f3)

    # 3. Skip if event type doesn't match
    if test "$CONF_EVENT" = "$EVENT_TYPE"; then 
        # 4. Skip if tool doesn't match and isn't '*'
        if [ "$CONF_MATCHER" = "$TOOL_NAME" ] || [ "$CONF_MATCHER" = "*" ]; then
            # 5. Increment matched count
            MATCHED=$[MATCHED + 1]
            # 6. Resolve script path
            if echo "$CONF_SCRIPT" | grep -q '^\./'; then
                SCRIPT_PATH=$(echo "$CONF_SCRIPT" | cut -c 3-)
                SCRIPT_PATH="$RUNNER_DIR/$SCRIPT_PATH"
            else
                SCRIPT_PATH="$CONF_SCRIPT"
            fi
            # 7. Print which script is running
            printf '%bRunning hook:%b %s\n' "$CYAN" "$RESET"
            # 8. Execute the hook script
            STDERR=$(mktemp)
            bash "$SCRIPT_PATH" < "$TEMP_FILE" 2> "$STDERR"
            EXIT_CODE=$?

            # 9. Handle exit code
            if test $EXIT_CODE -eq 0; then
                printf '%b✓ Passed%b\n' "$GREEN" "$RESET"
                PASSED=$((PASSED + 1))

            elif test $EXIT_CODE -eq 2; then
                printf '%b✗ BLOCKED%b\n' "$RED" "$RESET"

                if test -s "$STDERR"; then
                    printf '%b%s%b\n' "$RED" "$(cat "$STDERR")" "$RESET"
                fi

                BLOCKED=$((BLOCKED + 1))
                FINAL_EXIT=2
                printf '%bChain stopped because of BLOCKED hook.%b\n' "$RED" "$RESET"
                rm -f "$STDERR"
                break

            else
                printf '%b⚠ Warning (exit %d)%b\n' "$YELLOW" "$EXIT_CODE" "$RESET"
                if test -s "$STDERR"; then
                    printf '%b%s%b\n' "$YELLOW" "$(cat "$STDERR")" "$RESET"
                fi
                WARNINGS=$((WARNINGS + 1))
            fi
            printf '\n'
            rm -f "$STDERR"
        fi
    fi
done < "$CONFIG_FILE"

# ── Summary ────────────────────────────────────────────────────────────────────
printf '%b─── Hook Execution Summary ──────────%b\n' "$BOLD" "$RESET"
printf 'Matched:  %d hooks\n' "$MATCHED"
printf '%bPassed:   %d%b\n' "$GREEN" "$PASSED" "$RESET"
if [ "$BLOCKED" -gt 0 ]; then
    printf '%bBlocked:  %d%b\n' "$RED" "$BLOCKED" "$RESET"
else
    printf 'Blocked:  %d\n' "$BLOCKED"
fi
if [ "$WARNINGS" -gt 0 ]; then
    printf '%bWarnings: %d%b\n' "$YELLOW" "$WARNINGS" "$RESET"
else
    printf 'Warnings: %d\n' "$WARNINGS"
fi

exit $FINAL_EXIT
