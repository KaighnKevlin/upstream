# Art roadmap

Working notes for the recurring sprite/aesthetic passes. Newest entries at the
bottom of the log.

## Direction (from Kaighn, 2026-09-23)

- **Keep:** ore bouncing as a mechanic. The titan's clockwork look.
- **Clockwork is the house style for enemies:** bronze/brass bodies, visible
  gears and rivets, cyan glowing cores. The palette is the titan's 26 colours
  (`axe-titan-base.ase`).
- **Restyle:** ore and trampolines (the look, not the physics). Player sprite,
  goblin/skeleton/wizard (asset-pack chibis that clash), dome, HUD.
- The game was a proof of concept, so rewriting systems is fine.

## Pipeline

- `pixtools.py`: stdlib PNG/Aseprite read, PNG/GIF write.
- `titan_lib.py` + `gen_titan.py`: cut-out animation on the 427x687 reference,
  box-filtered into the palette. The rig includes IK arms, in-painting and smear.
- `gen_terrain.py`: terrain atlas.
- `frames_to_gif.py` + `tools/playtest.gd titan_vs_player`: in-game GIFs.
- For new clockwork enemies: paint at high resolution (shaded shapes, gears),
  then downscale with the same palette pipeline so they match the titan.

## Backlog

- [x] Titan walk (8) + two-handed chop (8)
- [x] Titan idle (6, core pulses) + death (8: buckle, pitch forward, axe drops, core fades)
- [ ] Titan second attack (sweep / ground slam)
- [ ] Clockwork replacements for goblin (small fast scuttler), skeleton
      (soldier), wizard (tesla caster)
- [ ] Player miner: redraw to sit with the clockwork world
- [ ] Ore and ingot look; trampoline redesign (spring-loaded brass plate)
- [ ] Dome (brass and glass), turret, receiver, laser, miner building
- [ ] HUD (brass frame, pixel font)

## Log

- 2026-09-23: terrain atlas, titan walk + chop, in-game GIF recorder.
- 2026-09-23 pass 1: titan idle + death. Rig now takes affine transforms (body tilt
  carries arms, pads and held axe), plus colour remap for the glow. In game: idle between
  chops; death plays the collapse, holds, then fades.
