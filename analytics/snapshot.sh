#!/usr/bin/env bash
# Pulls the live Team Alarm counts and rewrites analytics/latest.md.
# Run from the repo root:  bash analytics/snapshot.sh
set -euo pipefail
NS="d1n0s4urs-team-alarm"
API="https://abacus.jasoncameron.dev/get/$NS"
DIR="$(cd "$(dirname "$0")" && pwd)"
get() { local v; v=$(curl -s -m 10 "$API/$1" | sed -n 's/.*"value":\(-\{0,1\}[0-9]*\).*/\1/p'); [ -z "$v" ] || [ "$v" -lt 0 ] && v=0; echo "$v"; }
OUT="$DIR/latest.md"
{
  echo "# Team Alarm analytics"
  echo
  echo "Snapshot taken $(date -u '+%Y-%m-%d %H:%M UTC'). App: https://sicilyrose4.github.io/team-alarm-tasks/"
  echo
  echo "| Metric | Count |"
  echo "|---|---|"
  while IFS='|' read -r key label; do echo "| $label | $(get "$key") |"; done < "$DIR/keys.txt"
  echo
  echo "## Daily users (last 14 days)"
  echo
  echo "| Day | Users |"
  echo "|---|---|"
  for i in $(seq 0 13); do
    d=$(date -u -v-"${i}"d '+%Y-%m-%d' 2>/dev/null || date -u -d "-$i day" '+%Y-%m-%d')
    echo "| $d | $(get "day-$d") |"
  done
} > "$OUT"
echo "Wrote $OUT"
