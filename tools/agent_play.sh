#!/bin/sh
# Launch the blind-playtester harness (tools/scenarios/agent_rec.gd) in the
# background, the CLAUDE.md way: muted, one small window off-screen, SEED=1,
# caffeinated, and killed if no step lands for 11 minutes (the scenario itself
# gives up after 10 without a cmd). Puts manual.txt and step.sh in <out_dir>.
#   sh tools/agent_play.sh <out_dir>        REPLAY=<steps.jsonl> to replay
set -e
cd "$(dirname "$0")/.."
out="$1"; [ -n "$out" ] || { echo "usage: agent_play.sh <out_dir>"; exit 2; }
mkdir -p "$out"
out="$(cd "$out" && pwd)"
rm -f "$out/done" "$out/cmd.json" "$out/state.json"
python3 tools/manual_text.py > "$out/manual.txt"
cp tools/agent_step.sh "$out/step.sh"
(
  set +e   # a kill of an already-gone game must not end the watchdog
  SEED=1 godot --path . --audio-driver Dummy --windowed --resolution 1280x720 \
    --position 4000,4000 --script tools/playtest.gd -- agent_rec "$out" > "$out/godot.log" 2>&1 &
  p=$!
  caffeinate -dimsu -w $p &
  started=$(date +%s)
  while kill -0 $p 2>/dev/null; do
    sleep 5
    # it can hang on exit after the scenario is done: give it 5 s
    if grep -q '\] done$' "$out/godot.log"; then sleep 5; kill $p 2>/dev/null; break; fi
    if grep -qE 'SCRIPT ERROR|Parse Error' "$out/godot.log"; then echo "script error" >> "$out/godot.log"; kill $p; break; fi
    last=$(stat -f %m "$out/state.json" 2>/dev/null || echo "$started")
    if [ $(( $(date +%s) - last )) -gt 660 ]; then echo "watchdog: no step for 11 min" >> "$out/godot.log"; kill $p; break; fi
  done
  wait $p 2>/dev/null || true
  touch "$out/done"
) > /dev/null 2>&1 &
echo "started; log $out/godot.log"
