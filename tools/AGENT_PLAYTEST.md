# Agent playtests

An agent plays Upstream from screenshots with a person's inputs only (keys, screen clicks), one command file per turn. The game freezes between turns, so the agent can think as long as it likes.

## Pieces
- `tools/scenarios/agent_rec.gd`: the harness scenario. Its header documents the command protocol and state.json.
- `tools/agent_play.sh <out_dir>`: launches it muted and off-screen, with caffeinate, a watchdog and a rate-limited log. Env vars:
  - `START_SAVE=<save.json>`: start from a save (presses F9 after F)
  - `IDLE=<s>`: how long to wait for a command (use 3600 for experts)
  - `REPLAY=<steps.jsonl>`: replay a run (`REPLAY_THEN=poll` to carry on live)
  - `FILM=0`: no motion sheets, for clean perf numbers
- `tools/agent_step.sh` / `tools/agent_look.sh`: copied into the run folder as `step.sh` and `look.sh`. They are the player's only tools.
- `tools/agent_expert_prompt.md`: the expert-tester prompt. Fill in `{PT}`, `{REPO}`, `{GOAL}`, `{JOURNAL_START}`, `{STOP_STEP}` and `{QUIT_RULE}`.
- `scripts/pointer.gd`: game code reads the mouse through `Pointer`, so the harness never moves the real cursor.
- Run folders are `playtests/<date>-<goal>/` (gitignored). Reports are `playtests/<date>-<goal>.md` (committed).

## Running a session (the orchestrating Claude session)
1. `IDLE=3600 START_SAVE=... sh tools/agent_play.sh playtests/<run>`, then wait for `state.json`.
2. Spawn a subagent with the filled-in prompt, capped at about 60–80 steps. It keeps `journal.md` and ends with an END OF SESSION block and an F5 save.
3. To continue: quit the game (`sh <run>/step.sh '{"action":"quit"}'`), move the step files into `<run>/sessionN/`, and relaunch with `START_SAVE=<run>/sessionN/save.json` (steps restart at 0). The next subagent reads the journal first.
4. One game window at a time. Check `godot.log` size and `df -h` between sessions.

## Mac requirements
- Godot 4.7 on PATH as `godot`
- python3 with Pillow (`look.sh`, GIFs)
- A logged-in GUI session. The window renders off-screen, but macOS needs a display session; a headless Mac mini needs a dummy HDMI plug or screen sharing logged in.
- Run `godot --headless --audio-driver Dummy --import` once after cloning.

## State of the October 2026 runs
The run state (journals, saves, the blind report's run folder minus screenshots) is on the `playtest-state` branch:
- `2026-10-04-expert-tier1`: fresh game, goal all six tier-1 techs. Stopped after 3 sessions (about 140 played steps) with 0 techs. The findings are in its journal.
- `2026-10-04-expert-endgame`: from the mid-game save (`start_save.json`), goal Beam optics. Stopped at session 1, step 12; F5 save in `save.json`. Resume with `START_SAVE=playtests/2026-10-04-expert-endgame/save.json`.
- Still to do: finish the endgame run (about 240 steps), then write `playtests/<date>-expert.md` combining both runs. Open bugs: the NaN rider flood (it hit both runs), beam tap side lost on load, and assemblers and labs sinking 16 px per load.
