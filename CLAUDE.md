# Upstream

A Godot 4.7 (GDScript) 2D game: a Factorio-like factory built as a physical
marble machine. Ore rides tracks, rises in the Upstream (a magic tractor beam,
the only true power source), and runs through marble-run pieces that smelt,
sort, assemble and feed defences and research.

## Layout
- `scenes/` holds the pieces and actors: one `<piece>.gd` + `.tscn` each.
  `main.gd` is the world and title screen (F = Factory mode, `=` = Marble Siege).
- `scripts/build_system.gd` and `scripts/build_bar.gd` hold the build enum,
  scenes, ghosts, the bar's PIECES/CATS, icons and `ART_RECTS`.
- `scripts/track/` is the 1D track simulation. Marbles on a track are riders
  `(track, s, v)` and become RigidBody2D ore only in the air. It gives
  backpressure, determinism and scale.
- `scripts/hold.gd` holds the claim/release convention for pieces that grab ore.
- `scripts/tech.gd` holds the tech tree (START / TREE / CUT / MAKES).
- `scripts/*_works.gd` are the demo worlds (Marble Works and others).
- `tools/playtest.gd` is the scenario harness. Scenarios live in
  `tools/scenarios/<name>_rec.gd` with `static func run(t)`.
- `tools/agent_play.sh` runs `agent_rec`: an agent plays from screenshots,
  one command file per turn (keys, screen clicks), off-screen and muted.
  Reports go in `playtests/<date>-<goal>.md`.
- `tools/art/gen_*.py` are the sprite generators.

## Running tests
Kaighn uses this laptop while tests run, so:
- **Always mute:** `--audio-driver Dummy`.
- **Keep it out of the way:** one window at a time, small and off-screen. Never
  leave demo windows running. Don't kill a game window Kaighn opened himself
  without asking.
- macOS has no `timeout`, so use a watchdog. A parse error hangs the harness
  forever, so grep the output for `SCRIPT ERROR|Parse Error`.

```sh
( SEED=1 godot --path . --audio-driver Dummy --windowed --resolution 1280x720 \
    --position 4000,4000 --script tools/playtest.gd -- <scenario> /tmp/out & p=$!; \
  for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null; wait $p )
```

- After adding files or merging: run `godot --headless --audio-driver Dummy --import`.
- `build_new_rec` places every piece. Run it after registering pieces.
- Prefix long runs with `(caffeinate -dimsu -t 60 &) ;`, because a sleeping
  display throttles the window.
- Don't run two game windows in parallel for A/B numbers. They throttle each other.

## Adding a piece
A new piece is registered in: `build_system.gd` (enum, `_scenes`, ghost colour,
drag list), `build_bar.gd` (PIECES, CATS, icon case, scn map, `ART_RECTS`),
`main.gd` (status label), `tools/playtest.gd` (`build_new_rec` list),
`scripts/manual.gd`, and `scripts/sandbox_save.gd` PROPS for any saved props.
Build-bar icons are auto-fitted by `_bounds()`, so sprite pieces need an
`ART_RECTS` entry. Create sprites before the ghost early-return in `_ready`.
Read the mouse with `Pointer.world(self)` (`scripts/pointer.gd`), never
`get_global_mouse_position()`: the agent playtester points through it.

Parallel sub-agents work in worktrees (`.claude/worktrees/`) and only add
files. The main session does the registration above at merge time.

## Design direction
- Factory, not one-off toys. Advance the main game along the Factory Plan
  (https://claude.ai/artifact/1ymcn9sc82HJmz5revk4y1) rather than prototyping
  more standalone pieces.
- Track elements (gates, switches, sorters, counters, springs) should read as a
  real wood/brass marble machine. A visible lever, flap, spring or
  counterweight moves and causes the outcome. Settings are physical (slide a
  weight, move a peg), not click-to-cycle numbers.
- Every placed piece emits light (`scripts/piece_light.gd`). Darkness is
  currently off (`DARK_CAVES = false` in `main.gd`).
- Art inconsistency is fine while prototyping.

## Commits
Push to `main` after a clean import and test run. End commit messages with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
