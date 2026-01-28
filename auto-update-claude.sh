#!/bin/bash
# Auto-update Claude Code every 24 hours
# Usage: ./auto-update-claude.sh &  # run in background

UPDATE_INTERVAL=86400  # 24 hours in seconds

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

update_claude() {
    log "Checking for Claude Code updates..."

    CURRENT_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    log "Current version: $CURRENT_VERSION"

    npm update -g @anthropic-ai/claude-code >/dev/null 2>&1

    NEW_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

    if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
        log "Updated: $CURRENT_VERSION -> $NEW_VERSION"
    else
        log "Already up to date"
    fi
}

# First run
update_claude

# Loop
log "Next update in 24 hours..."
while true; do
    sleep $UPDATE_INTERVAL
    update_claude
    log "Next update in 24 hours..."
done
