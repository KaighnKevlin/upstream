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
- `clockwork.py`: 2.5D painter for new sprites. It builds figures from lit
  ellipsoids, capsules, gears and discs, renders them supersampled, and
  palette-maps with a 1px outline. Materials are BRONZE / STEEL / DARK / GLOW
  (emissive). Primitives are posed per frame, so animation is real joints.
  Example: `gen_scuttler.py`.

## Backlog

- [x] Titan walk (8) + two-handed chop (8)
- [x] Titan idle (6, core pulses) + death (8: buckle, pitch forward, axe drops, core fades)
- [x] Titan second attack: low rising sweep (8), used vs the player (MELEE vs_player); chop stays for the dome
- [x] Scuttler (replaces goblin): bronze beetle, gear, headlamp core, wind-up key
- [x] Tesla caster (replaces wizard): hovering orb, twin coils, arcs + discharge, cyan bolt
- [x] Clockwork soldier (replaces skeleton): shield + spear, walk (8) + thrust (6)
- [x] Player: prospector (brass helmet + headlamp, slate coat, brass tank): idle 4, run 8, jump 2. Kaighn's hand-drawn miner sheets kept as a fallback
- [x] Ore (3 rock+copper chunks, tumble), brass ingot, spring trampoline
- [x] Miner drill rig (4-frame pump, steam puff), arc smelter (brass electrodes + live lightning)
- [x] Dome observatory: glass (45% alpha) + brass ribs + riveted plinth with intake grate; cannon on the crown swivels to aim; ammo gauge strip on the rail
- [x] Titan third attack: stomp (8): axe raised, weight back, knee up, slam; shockwave sprite (gen_fx.py) rolls both ways along the ground
- [x] Scuttler pounce (6): crouch, tuck-and-leap, core overloads; it leaps onto the dome flank and detonates (blast does the damage)
- [x] Soldier death (7): spear slips and falls, kneels as the core gutters, topples onto its shield
- [x] Caster death (6): overload flash, thruster cuts, drops and tips over dark
- [x] Prospector hurt frame (recoil, eyes shut) + death (6, 64x40: reel, topple back, land, bounce, headlamp gutters out)
- [x] Backdrop: painted night sky + moon, far range, ruined clockwork city (towers, domes, sunk gears, smoking chimneys, lit windows), near ridge with a buried gear and pipe
- [x] Upstream shaft: Kaighn's drawing kept, stream animated (8 frames, currents + bubbles rising at ~lift speed)
- [x] Blunderbuss (brass, flared bell, steel bands, pressure gauge) + 3-frame muzzle flash/smoke + brass shot sprite (also the turret's rounds)
- [x] HUD: own 5x7 proportional pixel font (gen_font.py -> FontFile at runtime, scripts/pixel_font.gd), brass 9-slice panels, rimmed bars

## Log

- 2026-09-23: terrain atlas, titan walk + chop, in-game GIF recorder.
- 2026-09-23 pass 1: titan idle + death. Rig now takes affine transforms (body tilt
  carries arms, pads and held axe), plus colour remap for the glow. In game: idle between
  chops; death plays the collapse, holds, then fades.
- pass 2: clockwork.py painter; scuttler walk (6) replaces the goblin in game
  (EnemyType.GOBLIN renamed SCUTTLER).
- pass 3: clockwork.bolt() lightning; tesla caster hover (6) + attack (6), self-lit;
  enemy bolt restyled cyan with glow. WIZARD renamed CASTER.
- pass 4: soldier. Melee generalised: enemy.gd MELEE table (damage, cooldown, reach,
  impact frame, body offset, knockback) drives titan + soldier. SKELETON renamed SOLDIER.
  Player light 1.0 -> 0.7. All asset-pack enemies now replaced.
- pass 5: gen_items.py (ore/ingot/trampoline); clockwork.box() + render(extra=) for
  off-palette colours (copper). Trampoline arrow recoloured cyan. playtest loop_rec;
  _grab(div<0) = fixed px per world px (window size varies between runs).
  Next: miner building (purple block), laser, dome, receiver bar.
- pass 6: gen_machines.py (miner, electrode). Laser is now an arc: Line2D bolt + glow
  re-rolled every 40-90ms, cyan light. Next: dome, turret, receiver, then the player.
- pass 7: gen_dome.py. Turret moved onto the crown (1200, 36); receiver sprite hidden,
  the plinth grate stands in for it. Dome light 0.55 -> 0.4. Next: the player miner,
  then the HUD (brass frame, pixel font), then the upstream lift shaft art.
- pass 8: gen_player.py prospector, wired in via player_sprite.create_prospector_frames().
  Next: HUD (brass frame, pixel font), upstream lift shaft art, a mining swing animation
  for the prospector (the pickaxe is still the old polygon), titan second attack.
- pass 9: HUD. Font sizes must be multiples of 10 (integer scaling). Missing glyphs:
  $&*@\\^`{|}~ (add to gen_font.py G if needed). Next: lift shaft art, prospector
  pickaxe swing, titan second attack, wave banner.
- pass 10: titan sweep. MELEE entries can carry vs_player {anim, impact, knock, damage}.
- pass 11: prospector pickaxe (painted sprite, pivot at the shoulder) + 3-frame swing pose;
  swing mirrors by facing so it always chops down. Gameplay fix: sideways J-mining clears
  the full body height (was one tile, so you couldn't enter your own tunnel).
  Next: lift shaft art, wave banner, maybe a scuttler death, dirt/stone mining crack overlay.
- pass 12: clockwork deaths. debris.png (brass/steel gears, bolt, spring, plate, core glass);
  FX.debris() spawns physics bits (terrain-only collision, bounce 0.45, fade ~2s).
  Small enemies burst into 5-7 bits; the titan spills 8 from its core as it falls.
- pass 13: wave banner (brass plate drops in: WAVE n + roster), pulsing off-screen
  enemy marker with count (assets/ui/arrow.png), brass game-over plate. HUD labels use
  NEAREST filtering (linear bled the neighbouring atlas cell as thin bars).

### Pass 14 — pounce + small-enemy deaths
- clockwork.py: Figure.transform(deg, pivot, shift) rotates/moves a whole figure (topples, falls, leaps).
- gen_scuttler.py: scuttler_pounce.png. enemy.gd: within POUNCE_RANGE of DomeZone the scuttler commits (leaves "enemies", no collision), leaps on a tweened arc and _detonate()s: cyan/orange burst, steam, debris, light flash, damage_dome. Replaces silently vanishing into the dome.
- gen_soldier.py: soldier_death.png (spear composited separately so it falls on its own). gen_caster.py: caster_death.png. enemy.gd: _soldier_die / _caster_die play them, dust on landing, then fade.
- playtest: pounce_rec; deaths_rec gives each death time to play.

### Pass 15 — prospector hurt + death
- gen_player.py: frame 17 "hurt"; prospector_death.png at 64x40 (same centre as the 32x40 frames, so no offset juggling). build() takes rot/shift (Figure.transform), eye=False, lamp=0.
- player.gd: take_damage plays hurt for 0.3 s; at 0 hp _die(): input off, slides to a stop, death anim, light dims, then player_died after a beat instead of cutting straight to game over.
- main.gd: game-over plate names the cause (DOME DESTROYED / PROSPECTOR DOWN); "Waves survived" no longer shows -1.
- playtest: player_death_rec.

### Pass 16 — titan stomp
- gen_titan.py: STOMP poses via render_body (tilt, glow pulse); new 'front_lift' pose key slides the front leg up under the hip for a knee-up (a rigid leg rotation alone just kicks forward and hides behind the back leg). ONLY_EXTRA=1 skips re-rendering walk/attack/sweep.
- gen_fx.py (new): shockwave.png, 5 frames 48x24, a leaning crest of clods + dust skirt + chips, cyan spark early.
- enemy.gd: STOMP table. A player on the ground 40-150px away (beyond axe reach) triggers it on its own 5s cooldown; impact frame 4 spawns two shockwaves tweened outward, shake, dust. Grounded players in range take 8 and get launched up and away; jumping dodges it.
- playtest: stomp_rec.

### Pass 17 — backdrop
- gen_background.py (new, stdlib): assets/backgrounds/{sky,moon,far,city,near}.png. All layers tile at 960 (periodic sine noise, wrapped shapes), ordered 4x4 Bayer dithering, moonlit left-facing edges, haze brightening toward each layer's base so the silhouette in front reads.
- parallax_bg.gd: _build_painted() when the PNGs exist (else the old procedural layers). Motion: stars 0.05, moon 0.03 (untiled, one moon at any zoom; its screen x is roughly position.x * zoom), far 0.1, city 0.2, near 0.35. Sky is 4x1200 at native vertical scale (stretching it 2x made scanline bands).
- playtest: skyline (zooms 2, 1, 0.5 and an eastern view).

### Pass 18 — upstream shaft animated
- gen_upstream.py (new): reads upstream-sprite.png (Kaighn's art, left untouched), masks the stream blues, and draws rising current lines + bubbles on top; 12px/frame x 8 = 96px loop = the stream height, so it loops cleanly. A rising dithered light band was tried and dropped (read as a checkerboard stripe).
- upstream_shaft.gd: AnimatedSprite2D at 10 fps from upstream_anim.png, falls back to the still.
- playtest: shaft_rec (digs a pit, drops ore in).
- Not done on purpose: re-skinning it in brass. It's Kaighn's own design; ask before changing its look.

### Pass 19 — blunderbuss
- gen_weapons.py (new): blunderbuss.png 28x12 (grip at (7,7) = pivot), muzzle_flash.png 3x 20x16 (two burst frames + smoke), shot.png 8x4.
- shotgun.gd: sprite offset so the grip is the pivot; flip_v when aiming left so it stays upright; AnimatedSprite2D flash at the bell; pellets spawn at the muzzle; the prospector turns to face the shot.
- bullet.gd: shot sprite rotated along velocity every frame (turret rounds too).
- playtest: gun_rec (warps the mouse to aim, fires right then left).

