#!/bin/sh
# Launch the blind-playtester harness (tools/scenarios/agent_rec.gd) in the
# background, the CLAUDE.md way: muted, one small window off-screen, SEED=1,
# caffeinated, and killed if no step lands for IDLE + 15 minutes (the scenario
# itself gives up after IDLE s without a cmd, default 600; a seq of long waits
# can take 20 min). Puts
# manual.txt, step.sh and look.sh in <out_dir>.
#   sh tools/agent_play.sh <out_dir>        REPLAY=<steps.jsonl> to replay,
#                                           START_SAVE=<save.json> to start from a save
set -e
cd "$(dirname "$0")/.."
out="$1"; [ -n "$out" ] || { echo "usage: agent_play.sh <out_dir>"; exit 2; }
mkdir -p "$out"
out="$(cd "$out" && pwd)"
rm -f "$out/done" "$out/cmd.json" "$out/state.json"
python3 tools/manual_text.py > "$out/manual.txt"
cp tools/agent_step.sh "$out/step.sh"
cp tools/agent_look.sh "$out/look.sh"
(
  set +e   # a kill of an already-gone game must not end the watchdog
  # the log goes through a filter: an error repeated every frame (a NaN
  # body) once wrote 1.6 GB in two minutes. A line is kept 50 times, then
  # only counted (a note every 10000).
  rm -f "$out/.logpipe"; mkfifo "$out/.logpipe"
  awk '{ n[$0]++; if (n[$0] <= 50) print; else if (n[$0] % 10000 == 0) print "[repeated " n[$0] "x] " $0; fflush() }' \
    < "$out/.logpipe" > "$out/godot.log" &
  SEED=1 godot --path . --audio-driver Dummy --windowed --resolution 1280x720 \
    --position 4000,4000 --script tools/playtest.gd -- agent_rec "$out" > "$out/.logpipe" 2>&1 &
  p=$!
  caffeinate -dimsu -w $p &
  started=$(date +%s)
  while kill -0 $p 2>/dev/null; do
    sleep 5
    # it can hang on exit after the scenario is done: give it 5 s
    if tail -n 20 "$out/godot.log" | grep -q '\] done$'; then sleep 5; kill $p 2>/dev/null; break; fi
    # a parse error hangs it before the first step; later SCRIPT ERRORs are findings
    if grep -q 'Parse Error' "$out/godot.log" || { [ ! -f "$out/state.json" ] && grep -q 'SCRIPT ERROR' "$out/godot.log"; }; then echo "script error" >> "$out/godot.log"; kill $p; break; fi
    last=$(stat -f %m "$out/state.json" 2>/dev/null || echo "$started")
    if [ $(( $(date +%s) - last )) -gt $(( ${IDLE:-600} + 900 )) ]; then echo "watchdog: no step for IDLE + 15 min" >> "$out/godot.log"; kill $p; break; fi
  done
  wait $p 2>/dev/null || true
  rm -f "$out/.logpipe"
  touch "$out/done"
) > /dev/null 2>&1 &
echo "started; log $out/godot.log"
