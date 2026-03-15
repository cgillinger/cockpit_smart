#!/bin/bash
# smart-history.sh — Kör smart-collect.sh och appendar resultatet med timestamp
# till /var/log/smart-history.json (JSONL-format, en rad per körning).
# Avsett att köras via cron dagligen.

set -euo pipefail

HISTORY_FILE="/var/log/smart-history.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT_SCRIPT="$SCRIPT_DIR/smart-collect.sh"

# Kör smart-collect.sh och fånga output
SMART_DATA=$("$COLLECT_SCRIPT" 2>/dev/null) || {
    echo "smart-history: smart-collect.sh misslyckades" >&2
    exit 1
}

# Skapa en JSONL-rad: {"timestamp": "...", "disks": [...]}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

python3 -c "
import json, sys

timestamp = '$TIMESTAMP'
disks = json.loads(sys.stdin.read())

record = {'timestamp': timestamp, 'disks': disks}
print(json.dumps(record, separators=(',', ':')))
" <<< "$SMART_DATA" >> "$HISTORY_FILE"
