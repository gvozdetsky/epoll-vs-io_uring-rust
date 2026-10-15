#!/usr/bin/env bash
# The i9's side of the night of 2026-10-14/15: runs night.sh i9, copies
# the laptop's results over every 20 minutes (the laptop runs night.sh i7
# on its own), and at the end writes SUMMARY.md next to both.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
NIGHT=results/night-2026-10-15
HOURS="${1:-9}"
LAPTOP="${LAPTOP:?set LAPTOP to the SSH user@host of the i7}"
LAPTOP_DIR="${LAPTOP_DIR:-ruxen-bench/article}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20)
[[ -z "${SSH_IDENTITY:-}" ]] || SSH+=(-i "$SSH_IDENTITY" -o IdentitiesOnly=yes)
mkdir -p "$NIGHT/i9" "$NIGHT/i7"

sync_laptop() {
    rsync -a -e "${SSH[*]}" "$LAPTOP:$LAPTOP_DIR/$NIGHT/i7/" "$NIGHT/i7/" 2>>"$NIGHT/sync.err"
}

summary() {
    python3 scripts/summarize.py "$NIGHT/i7" "$NIGHT/i9" >"$NIGHT/SUMMARY.md" 2>>"$NIGHT/sync.err"
}

( while true; do sleep 1200; sync_laptop; summary; done ) &
syncer=$!

scripts/night.sh i9 "$NIGHT/i9" "$HOURS"

# The laptop started at the same time; give it until an hour past the
# deadline to finish its last phase.
end=$(( $(date +%s) + 3600 ))
while (( $(date +%s) < end )); do
    sync_laptop
    grep -q DONE "$NIGHT/i7/night.log" 2>/dev/null && break
    sleep 300
done
kill "$syncer" 2>/dev/null
sync_laptop
summary
echo "[$(date '+%F %T')] wrapper done" >>"$NIGHT/i9/night.log"
