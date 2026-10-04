#!/bin/sh
# One turn of the blind playtester: send a command, wait for the game to run
# it, print the new state.json (its "shot" is the screenshot to look at).
#   sh step.sh '{"action":"key","key":"D"}'
# Run from the playtest folder (or set PT_DIR).
d="${PT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
before=$(sed -n 's/.*"step": \([0-9]*\).*/\1/p' "$d/state.json" 2>/dev/null)
printf '%s' "$1" > "$d/cmd.json.tmp" && mv "$d/cmd.json.tmp" "$d/cmd.json"
case "$1" in *'"quit"'*) echo "quit sent"; exit 0;; esac
i=0
while :; do
  now=$(sed -n 's/.*"step": \([0-9]*\).*/\1/p' "$d/state.json" 2>/dev/null)
  if [ -n "$now" ] && [ "$now" != "$before" ]; then cat "$d/state.json"; echo; exit 0; fi
  if [ -f "$d/done" ]; then echo "GAME ENDED (see godot.log)"; exit 1; fi
  i=$((i + 1)); [ $i -gt 9000 ] && { echo "TIMEOUT: game did not answer in 15 min"; exit 1; }
  sleep 0.1
done
