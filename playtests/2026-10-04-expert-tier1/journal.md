# Upstream expert playtest: tier 1 (session 1)
Goal: research all six tier-1 techs from a fresh Factory game with a proper factory. Tester: Claude (expert QA), file harness.
Notes from source: flask = gear + Cu ingot, gear = Cu ingot + Fe ingot -> 2 Cu ore + 1 Fe ore per flask; 6 techs x 5 = 30 flasks = 60 Cu + 30 Fe ore minimum. Veins 6 ore/tile. Beam 2/s, crown at surface (y 100), spills right. Camera zoom 1.5 (1 tile = 24 screen px).

000 | doing: start | saw: starter pit, Beam (2.0/s label), copper vein right of pit above ironstone band, iron ore in dirt just below pit floor level to the right; bar shows tapper, track rail, assembler, lab (+ more tabs)
001 | doing: zoom out x2 to survey | saw: zoom 1.0; pit 1168-1248 world, beam at x1240 in the pit's right column; ironstone (pick-proof) bands right of pit rows 11-13 and under pit floor
002 | doing: zoom out to 0.5 | saw: whole 150-tile map; big natural cavern right of the pit (x~1660-1935, y~224-448), copper starter vein on top of the band right of pit, iron starter vein at ~x1650 rows 8-9
003 | doing: D+J 3 s from pit floor | saw: dug a 3-tall hall rows 15-17 right of the pit, 200 px in 3 s (fast, satisfying)
004 | doing: D+J 2.5 s more, zoom in | saw: hall reaches x~1584, just short of the cavern's left lobe; band gap at x1600-1663
DESIGN (planning, 000-004): read the numbers before building. Vein tapper fires every 1.4 s fixed (eject_interval is not player-adjustable; UI sets only angle/force), so one tapper drains a 4-tile starter vein (24 ore) in ~34 s, while an unpowered gear assembler takes 5.1 s per gear and the lab 7.1 s per flask. Ore lifetime is 15 s and ground ore fades after 4 s, so at tier 0 (no bins, no splitter) 60-80% of tapped ore is simply lost unless something buffers it. The only buffer is the Beam's foot queue (waiting pieces have timers reset), which only engages when the beam is saturated.
DESIGN (planning): copper is scarce: copper only scatters below row 40 (y 640+); near the surface there are just 3 starter copper veins (<=4 tiles = <=24 ore each, <=72 total) vs 60 copper ore for the 30 tier-1 flasks before any waste.
DESIGN (planning): furnace rail max length is 220 px (chute LEN_MAX), but unpowered smelting needs 2.0 s of dwell; a beam tap ejects at a fixed 150 px/s, so ore tapped onto a downhill furnace rail leaves raw (~1.3 s). The factory_t0 scenario uses a 250 px rail placed in code, longer than a player can lay.
005 | doing: sent D+J 1.2 s + zoom in | saw: no answer; godot.log says "no cmd for 600 s: giving up / quit after 4 steps". My planning between steps 4 and 5 ran over the harness's 600 s idle timeout and the game quit. Nothing was saved (no F5 yet). The command is still sitting in cmd.json.
BUG (harness, minor): the agent harness quits after 600 s without a command, with no warning in state.json, and the exit logs "ERROR: 1 resources still in use at exit" plus 11 leaked ObjectDB instances (at quit, so probably harness teardown, not gameplay).
DESIGN (seed geometry, 001-004): the pick-proof ironstone ledges sit exactly where a stepped line wants to go: rows 11-13 right of the pit (x1250-1600), rows 10-11 left of the pit (x1040-1164), rows 18-20 under the pit floor. A t0-style staircase (G, F 48 px lower, lab 48 px lower, rail 75 px above G = ~190 px of height) does not fit beside the Beam on either side; the only band-free columns are the pit itself, the gap at x1600-1663 and the natural cavern at x1660-1935.

== END OF SESSION at step 4 (game quit on idle timeout) ==
Factory state: nothing built, nothing saved. Only change: a 3-tall hall dug right of the pit floor, rows 15-17 (y 240-288), from the pit (x1248) to x~1584. Techs: none. game_s 10.8.
What I was doing: surveying the terrain and designing the line before placing pieces.
World notes (zoom 1.0: screen = world - camera offset; the Beam crown is at (1240,100), foot at y 288, pit x1168-1248, tile 16 px):
- Copper starter vein: tiles 84-86 (x1344-1392), row 10, sitting on top of the band right of the pit; dirt rows 7-9 above it (dig them to open its top face).
- Iron starter vein: tiles 103-104 (x1648-1680), rows 8-9, just under the grass right of the band gap.
- Iron veins in dirt below the hall: x1376-1411 rows 18-20 (its top is the hall floor), x1361-1386 rows 21-23, x1453-1470 rows 23-26.
- Two more copper starter veins far left (x~720-880, rows 9-13).
- Cavern: left lobe x1503-1660, ceiling ~y300, floor ~384; main part x1663-1935, ceiling 224-281, floor 400-448.
Plan for next session (beam-centric, because the beam foot is the only tier-0 buffer):
1. Dig the upper tunnel rows 7-9 from the pit to x~1680 (reach it via the stairs to the surface, then S+J down at x~1300). Put a copper tapper on tile 85 or 86 and an iron tapper on tile 103 that lob steeply onto track rails running down-left along the tunnel into the pit, then zig-zag down inside the pit to end at the Beam's foot (1236,284). Riders on a track are not grabbed by the Beam, so raw ore enters at the foot, below every tap.
2. Taps at least 30 px apart (build distance rule): iron (left, y~150), copper (left, y~200), both dropping onto one shallow furnace rail on the pit/stair floor (1106,268)->(1222,284) that drains back into the foot. Furnace dwell is kept per piece id across passes, so raw pieces that come back unsmelted just loop until they smelt.
3. Ingot tap (right, y~250) -> track rail along the hall -> into the cavern lobe, the last segment coming down onto G's funnel from the left, so G's left-spat surplus lands back on the rail and rolls back into G (right-spat surplus goes on toward F).
4. G (gear) on the lobe floor (~x1580, floor 384), F (flask) ~60 px right and 48 px lower, lab ~71 px right and 48 px lower (dig the cavern floor for it). Then F5.
Things to measure: beam usage/queue once raw ore + ingots both ride it (each ore passes twice); pile-up at the foot (bodies, perf); copper per flask actually spent; game_s per tech.
Findings so far, ranked:
1. DESIGN: fixed 1.4 s tapper interval vs 5-7 s unpowered machines; with 15 s ore lifetime most tapped ore is wasted at tier 0, starter veins drain in ~34 s.
2. DESIGN: copper scarcity: <=72 shallow copper vs 60 needed for tier 1 before waste; deep copper (y 640+) needs lifting.
3. DESIGN: furnace rail max 220 px vs 2.0 s unpowered dwell and 150 px/s tap ejection; t0 scenario relies on a 250 px rail.
4. DESIGN: ironstone ledges block stepped lines beside the Beam in this seed.
5. BUG (harness): silent 600 s idle quit; exit-time resource ERROR.

== SESSION 2 starts at step 0 (fresh restart) ==
000 | doing: fresh Factory game | saw: same seed as session 1 (player 1200,269 in starter pit)
Plan this session: surface factory right of the dome (open air, no build range limit). Furnace rails float in the air; copper tapper on starter copper tiles 84-86, iron tapper on tiles 103-104; G on grass, F one step down, lab another step down in the band gap (x1600-1663).
001 | doing: D+J 6.5 s re-dig hall rows 15-17 to the cavern | saw: reached x1619 in 6.5 s; cavern big, salvage cache floating in it
002 | doing: walk back left | saw: pit is open to the sky under the dome
003-007 | doing: grappling hook up the pit wall to climb out (3 tries) | saw: hook bites the wall low and hangs at y~199; tapping/re-pressing Shift drops you; never got out
DESIGN (003-007): no way up out of the starter pit except the stair cut on the left; the hook only bites where its line first touches the wall, so in a narrow shaft it can't climb more than a few tiles. Climbing out to work on the surface cost ~12 steps.
008-010 | doing: climb stair cut (A + tapped Space), walk right on grass | saw: walking right toward the dome drops you down the pit (dome glass is walk-through at its base), back in the hall
011-016 | doing: climb stairs again | saw: the stair top is a cut below grass; walking right descends it again to the pit. Copper starter vein (cols 49-50, rows 9-11) beside the stair top, no iron near it
017-018 | doing: jump right + steam jump from the stair top | saw: landed ON the dome glass (solid from above), walked off onto grass at x1441
DESIGN (008-018): getting from the pit to the surface east of the dome is a maze: the stair cut leads west only, the dome's base doesn't cover the pit (you fall back in) but its glass is solid from above. ~18 steps of the 300 cap spent just walking.
019-020 | doing: S+J down onto copper tiles 84-86, widen | saw: 3 copper tiles exposed (x1344-1392, top y160)
021 | doing: placed 2 copper tappers to test | saw: they start firing the instant they're placed (default aim up-left into the pit wall)
022 | doing: RMB both tappers to save the vein | saw: removed, vein keeps its ore
DESIGN (021): a vein tapper has no off switch and starts firing at its default aim the moment it lands, so every second spent aiming (click body, drag handle, check arc, re-drag) spends finite starter ore. Placing it is the only way to see its arc.
023-028 | doing: dig trench for F (floor y176), lab pit (floor y224, gap x1600-1648), expose iron tile 103 | saw: ok; iron starter vein is really 103 row 8 + 103-104 row 9 (tile 104 row 8 was dirt)
029 | doing: G (1469,96) on grass, F (1553,176) in trench, lab (1624,224); furnace rail 1 (1290,22)->(1466,32) over G, rail 2 (1745,80)->(1556,92) over F | saw: all placed, rails float on drawn posts
030-031 | doing: G recipe Gear, F recipe Flask, lab -> Buffers & metering | saw: research screen clear, lab label "Buffers and metering [0/5]"
032-035 | doing: copper tapper A (tile 84) straight up onto rail 1, copper B (tile 86) long lob to rail 2, iron (tile 103) lob left to rail 1 | saw: iron placement refused twice (I was standing on tile 103 / tile 104 was not ore: no feedback why); copper B landed on rail 2 but bounced and rolled off its high (right) end onto the grass
036 | doing: furnace rail 3 as a bank at rail 2's high end (1800,40)->(1747,79) | saw: works: ore runs up it and back; copper INGOTS came off rail 2, but they overshot F's funnel to the left
037 | doing: re-lay rail 2 shorter (1747,79)->(1570,90) | saw: RMB on the middle of a rail does nothing: removal only finds a piece within 50 px of its origin (the rail's high end)
DESIGN (037): RMB removal measures distance to each piece's origin only, so long rails/chutes can only be removed by clicking their start end.
037 | saw: both copper tappers grey: the 3-tile starter vein (18 ore) was empty ~18 s after placing two tappers on it
038-039 | doing: watch rail 1 | saw: an iron ore resting on rail 1; then fps fell to 6 and the log filled with ~20 million lines
BUG (038-040, step_039.png): "ERROR: Offset is non-finite at sample_baked (curve.cpp:556)" + "Vector2 cannot be normalized, elements must be finite" spammed ~200k lines/s (25k ERROR lines in state.json at step 39); fps_avg 6, worst frame 214 ms. Looks like one physics piece (ore/ingot) got a NaN position and its flight trail (Line2D width_curve, scripts/flight_trail.gd) samples a NaN offset every frame. It stopped by itself ~20 s later when the piece's lifetime ran out (bodies 4 -> 1). Started right after the iron tapper fired at rail 1 / an ingot lay on the trench floor beside F; cause not pinned down.
PERF (039): the NaN spam above drops the game to 6 fps for ~20 s and wrote a 23-million-line godot.log.
040 | doing: wait 15 s | saw: errors stop; all 3 tappers grey: iron starter vein (4 tiles) also empty. G and F show no held-item pips. Net result: both east starter veins (copper 18, iron ~24) spent, 0 ingots into G, 0 gears, 0 flasks.
BUG? (040): assembler pips/progress bar are drawn in the node's _draw at y-37/-8, i.e. under its own AnimatedSprite child, so they may never be visible (couldn't see any all run).
DESIGN (021-040, biggest so far): tier 0 cannot afford trial and error. The two east starter veins (~42 ore, enough for ~5 flasks with zero waste) were gone in ~25 s of game time while I aimed three tappers. Combined with always-on 1.4 s tappers and no buffer, the bootstrap fails on the first mis-aim.
041-044 | doing: relocate toward the beam: off the surface into the hall | saw: player got stuck standing in F's funnel (couldn't walk off, only jump out); removed the lab (RMB) to dig down through its pit; S+J overshot through hall floor into the cavern lobe
DESIGN (041): the assembler funnel traps the player: standing on it, A/D do nothing until you jump.
045-050 | doing: climb back into the hall from the lobe (jump + steam jump under my hole) | saw: works on the 2nd try; jump 420 + steam 336 clears ~96 px
051-052 | doing: dig row 18 over the iron vein under the hall floor (cols 86-87, iron rows 19-20), tapper on col 87 aimed flat left at the beam (force ~700) | saw: placed; first drag missed the handle (handle sits at pivot y-21 above the vein top, not the cell)
053 | saw: the flat shots (~690 px/s) cross the beam column at hall height and land on the stair-cut floor left of it; beam usage stays 0.0
DESIGN/BUG? (053, step_053.png): fast pieces go straight through the Beam. Its pull is a velocity lerp of 5*delta (~8% per frame), so a piece at ~700 px/s crosses the 26 px column in 2 frames, and the gauge never counted one as admitted. A lob "into the beam" has to arrive slowly (drop in at the foot or roll in).
055-056 | doing: re-aim to land just right of the beam and roll in (clicking the body again DESELECTS it, so my drag hit nothing the first time) | saw: one iron ore came to rest inside the column at the foot (step_057), sat there >1 s, then was gone 1.5 s later with no gauge reading
DESIGN (055): clicking a selected tapper's body toggles it off, so "click to select, then drag" fails silently every other time.
057-059 | saw: the hall iron vein (~3 tiles, ~18 ore) is empty after ~25 s too. Beam test inconclusive: no ore source left nearby.
060 | doing: Escape, F5 | saw: SAVED "9 pieces and the terrain"

== END OF SESSION at step 60 ==
Goal not reached. Techs: none. game_s 206. Saved at step 60 (F5, run slot).
Factory state (all idle, no ore left anywhere near it):
- Surface east of the dome: G (Gear) at (1469,96) on the grass; F (Flask) at (1553,176) on the band top in a trench (x1516-1648, floor y176); furnace rail 1 (1290,22)->(1466,32) floating over G; furnace rail 2 (1747,79)->(1570,90) over F with a bank rail 3 (1800,40)->(1747,79) at its high end (the bank works: ore runs up and back). Lab REMOVED (its pit x1600-1648 is now dug down through the hall into the cavern lobe).
- Three spent tappers on the surface: copper on tiles 84 and 86 (x1352/1384, top y160; vein empty), iron on tile 103 (x1656, top y128; vein empty). One spent iron tapper in the hall floor at (1400,304).
- Digging: pit over the copper tiles x1325-1424 rows 6-9; trench + lab pit as above; hole x1600-1632 from the trench down to the lobe; small depression in the hall floor x1326-1408 rows 18-19.
- Player in the hall at (1416,269). The lab's research choice was Buffers & metering.
What I learned about the geometry/flow:
- The east starter veins (copper tiles 84-86, iron 103-104) and the hall iron vein are gone. Ore left near the surface: two WEST copper starter veins (one at cols 49-50 rows 9-11, x785-815, beside the stair-cut top; the other further west), and iron in the dirt below the hall (x1358-1388 rows 21-23, x1453-1475 rows 23-26, under the cavern floor x1535-1561 and x1627-1680). Copper below row 40 (y640+) only.
- The Beam crown spills RIGHT (spill=1) at (1256,96) with v=(110..150,-170): it lands on the grass at about x1290-1310, y96. So nothing the Beam lifts can reach the current surface rails (y22-90) or G's funnel (y38): a beam-fed factory must sit BELOW grade east of the dome. That is why the surface layout was a dead end once the starter veins were gone.
- Beam taps on the right side can only shoot into the hall (y240-288); higher up the pit's right wall is 8 px away. Left-side taps shoot into the pit/stair cut.
- Pieces must enter the beam slowly (see 053).
Plan for next session:
1. F9 is optional (the save is just this state). Decide first whether to rebuild around the beam (the design's loop) or around direct tapper lobs.
2. Suggested beam loop: dig a below-grade basin right of the dome over the band (rows 6-10, x1260-1480; the band top y176 is a pick-proof floor). Lay a furnace rail RISING to the right from about (1265,95) under the crown spill so spilled ore lands moving right, climbs, stops, rolls back left and drops off its low end back into the pit -> beam (dwell is kept per piece across passes, so it loops until smelted; pieces in the beam/foot queue never expire, so this is also the only tier-0 buffer). Then a right-side "ingot" beam tap at y~250 shoots ingots into the hall toward G in the hall/lobe (F one step down in the lobe, lab in the main cavern, floors are dirt so steps can be dug).
3. Feed the beam with iron tappers under the hall floor aimed to drop ore gently onto the pit floor at x1230-1250, and copper from the west veins (lob ~430 px east across the stair cut so it lands near the beam foot). Check the gauge reads usage > 0 before building further.
4. Expect copper to run out: 2 copper ore per flask, west veins ~24-48 ore. Deep copper needs a long tapper lob up a shaft (a tapper's max force 1400 px/s reaches ~1000 px straight up, so it can act as a lift).
Findings so far, ranked:
1. DESIGN: the tier-0 bootstrap can't survive trial and error. Tappers fire every 1.4 s from the moment they're placed, with no off switch and aim set only after placing, on finite veins (a 3-tile vein = 18 ore lasts ~25 s; two tappers on it ~13 s). I spent all ~60 ore of the three veins near the dome while aiming and got 0 gears/flasks. Suggest: tappers placed paused (click to start), or the arc preview on the ghost before placing, or a much slower default interval.
2. BUG + PERF (038-040): NaN piece -> "Offset is non-finite (curve.cpp sample_baked)" + "Vector2 cannot be normalized" spam, ~25k ERROR lines in one step, 23M-line log, 6 fps for ~20 s until the piece's lifetime ended.
3. DESIGN/BUG?: fast pieces fly straight through the Beam (weak velocity lerp); the gauge doesn't register them.
4. DESIGN: the beam crown spills at grass level, so anything above grade (my whole surface factory) can never be fed by the Beam; nothing in game says so.
5. DESIGN: getting around near the start is costly: pit only exits west by the stair cut, dome glass is solid from above but its base doesn't cover the pit, the hook only climbs a few tiles in a narrow shaft, the player gets stuck in an assembler funnel. ~25 of 60 steps were walking/climbing.
6. DESIGN (UI): RMB removal only finds a piece within 50 px of its origin (a rail's high end); clicking a selected tapper's body deselects it, so the next drag misses; the iron tapper refused placement twice with no reason shown (the tile I clicked was dirt, not ore).
7. BUG?: assembler held-item pips/progress bar are drawn under its own sprite, so you never see them (no feedback on what G/F hold).
8. DESIGN (carried from session 1): copper scarcity (shallow copper ~72 ore in 3 starter veins vs 60 needed for 30 flasks before waste); furnace rail 220 px max vs 2 s unpowered dwell.
Untested: vein_left (ore left per vein tile) is a static dict that the save doesn't store, so a partly tapped tile may refill to 6 after quitting and loading.

== SESSION 3 starts at step 0 (loaded from session 2 save) ==
Planning note: besides the source, I read the run's own save.json tile list (PT/save.json) to map ironstone/ore precisely; positions below are tile (col,row), 16 px tiles.
DESIGN (planning, from save.json): copper above row 40 is ONE vein: (49-50, 9-11) west of the stair cut, 4 tiles = 24 ore = 12 flasks at zero waste, vs 30 flasks (60 Cu) for tier 1. The nearest deep copper (col 93 rows 40-42) is sealed under ironstone (93,39) so no tapper can sit on it; the rest is at rows 44-77 (y 704+), 400-900 px below the Beam's foot, with an ironstone layer (rows 38-40, cols 75-101) in between. All six tier-1 techs need a deep-copper expedition that tier-0 pieces can barely do (only a tapper lob can lift).
DESIGN (planning): ore and ironstone are both pick-proof, and the ironstone under the hall is a staggered barrier (row 19 cols 64-67, row 20 cols 68-77, row 21 cols 78-81, row 20 cols 82-85). With the fixed 150 px/s beam-tap ejection and the assembler's fixed right-hand spout, the G->F->lab staircase only fits where floors are exactly 48 px apart and 60/71 px across; next to the Beam every candidate spot is blocked by a ledge or an ore tile by a few pixels.
001 | doing: zoom out to survey | saw: zoom ~1.27, whole hall/cavern; session-2 pieces where the save says
002 | doing: zoom back in | saw: ok
003 | doing: walk right along the hall | saw: walked off the shelf end into the main cavern, player (1619,381) on (100,25)
004 | doing: tap D + click-mine (102,26) | saw: momentum carried me 55 px further and the camera hadn't settled, so the click mined (105,27) instead; player (1674,413)
005 | doing: click-mine (102,26) for F's floor and (106,27) for the lab | saw: both gone (F floor now 432); click-mining any tile within 3 tiles is precise once the camera is still
006-007 | doing: inch right, click-mine (106,28) | saw: done; I had my floor arithmetic off by a row (lab needs (106,29) gone too, floor 480)
008-009 | doing: click-mine (105,27), S+J to deepen the lab pit | saw: S+J dug 2 rows in 0.3 s; lab pit is now cols 104-106 down to floor 496. Re-planned: G (1563,384) col 97, F (1636,448) col 102 on iron (102,28), lab (1707,496): steps of 64 and 48
010-011 | doing: jump out, click-mine (102,27),(103,27) | saw: done, F's floor is now iron (102,28) top y448
012 | doing: place F (1636,448) and lab (1706,496), one click on F's recipe | saw: both placed on the right floors; lab label 'Routing (0/5)' by default
013 | doing: place G (1563,384), set G=Gear, F=Science flask | saw: G sits under the 1-tile shelf end (rim y326, shelf underside y304); icons show gear and flask
014 | doing: click lab | saw: research screen, all six tier-1 open at red 0/5
015 | doing: pick Processing (gear stamp = gear from 1 iron ingot, no copper: the only way to stretch 24 Cu) | saw: lab 'Processing [0/5]'
016-017 | doing: hop left over F to (99,24); jump + steam jump to reach the shelf above G | saw: reached y~290 but drifting left too late, fell back
018-020 | doing: jump attempts from G's cabinet to the shelf | saw: wedged under the shelf corner (head at 307), then a D-tap+jump threw me onto F's cabinet (1661,389). 4 steps lost to platforming
021 | doing: grappling hook at the hall ceiling over the shelf, hold Shift 1.2 s | saw: reeled up and dropped onto the shelf (1574,269). The hook works well when aimed past the corner
022-023 | doing: inch left, click-mine shelf tiles (95,18),(96,18) | saw: done; I'm on a 2-tile island (97-98,18) above G
024-026 | doing: Marble tab, place beam tap right of the Beam at y262, click filter | saw: tap on the Beam (spout right), banner 'takes out: grit' after 3 clicks. (025: my seq had 11 commands and was refused whole, a wasted step)
027 | doing: tap filter -> ingot; lay track rails R1, R2 along the hall | saw: R1 refused silently (its start was 22 px from the tap: the 30 px spacing rule applies to a rail's start point too), R2 placed ~6 px low (camera y offset)
028-029 | doing: re-lay R1 from (1272,280) (34 px from the tap) to R2 | saw: R1+R2 track joined, (1272,280)->(1476,284)->(1508,286). Tap actually sits at y268 (camera y offset)
030-031 | doing: walk left along the hall | saw: fell into my own shelf notch, hopped out; now in the depression (1340,301)
032 | doing: furnace rail FRp in the pit (1135,271)->(1235,291) from the stair step down into the Beam's foot; two LEFT taps: copper at y232, iron at y196 (raw ore rising is thrown back onto FRp, dwell adds up per piece until it smelts; ingot tap at y264 sends ingots right onto R1) | saw: all placed, 18 pieces
DESIGN (032): with no buffer at tier 0, the ingot stream can't be matched to the assemblers. A tapper fires 0.71 ore/s; unpowered G takes 5.1 s per gear and holds 3 of each ingredient, so G overflows within seconds and spits the surplus left or right at random. F's copper can ONLY come from G's right-hand spit, so each flask costs ~3 copper (1 in the gear, 1 to F, 1 spat left and lost), and anything faster than ~0.3 Cu/s is wasted outright. The only throttle I have is removing the tapper (the vein keeps its ore) and re-placing + re-aiming it later.
033-035 | doing: walk to col 91, S+J 1.3 s to sink a 3-wide shaft (cols 90-92) toward iron (91,24) | saw: rows 18-22 dug, standing on row 23
036-037 | doing: S+J row 23; jump with A+J mid-air | saw: the mid-air A+J dug (88,18),(89,18) and threw me out onto the old tapper (1389,285)
038 | doing: step right into the notch, S+J twice | saw: cols 87-89 rows 18-21 open; together with the shaft a clear channel up-left from iron (91,24) to the hall
039 | doing: place iron tapper on (91,24), select, drag handle to aim 37 deg left, 530 px/s | saw: placed+aimed in one seq, but I was standing in the channel: picked up 3 iron ore (player ore=3), and 2 raw iron are riding R1 toward G (the default-aim shots before my drag)
040 | doing: hop out of the channel, Escape, wait 3 s | saw: NaN FLOOD again: ~50 'ERROR: Offset is non-finite at sample_baked (curve.cpp:556)' lines, fps_avg 4, worst frame 271 ms, physics_ms 34. Raw iron ore resting on R1 (track rail, 1.1 deg, too flat: riders stop on it) and R2's short end
BUG (040, step_040.png): NaN flood reproduced. Just before: iron tapper (1464,376) firing up the channel; several raw iron ore landed on track rail R1 (1272,280)->(1476,284) and sat still on it (3 riders), 3 loose ore, the old spent tapper (1400,304) right under R1, the player had just absorbed 6 iron by standing in the shot path. Session 2's flood also began with an iron ore resting on a rail. Common factor: iron ore at rest on a near-flat rail.
DESIGN (039-040): standing in a tapper's line of fire silently eats the ore into your gun ammo (ore=6), with no warning while you aim.
041 | doing: RMB R1, re-lay it steeper (1272,274)->(1476,284) | saw: R1 re-laid; an INGOT just left the ingot tap (iron smelted on FRp: the pit loop works); still NaN spam, fps 4
042 | doing: wait 5 s | saw: still flooding: godot.log now ~11 million 'Vector2 cannot be normalized' warnings (WARNINGs, so state.json errors shows 0), fps 2, physics_ms ~67. It has lasted >35 game-s, longer than an ore lifetime, so the NaN body is probably one whose timer keeps being reset (in the Beam?) -> F5 + F9 to drop loose bodies
043 | doing: F5 then F9 (save, reload) to clear loose bodies | saw: saved (save.json 12:18) and reloaded (loose_ore 7->1), but the flood continues (13.8M warnings, fps 2): a reload doesn't stop it, so something keeps re-creating the NaN
044 | doing: RMB the iron tapper (stop all new ore), wait 10 s | saw: flood continues with loose_ore 0, bodies 2, but riders 2 and physics_ms ~59: suspect riders stuck on R1/R2
045-046 | doing: RMB R2 and R1 (dropping their 2 riders), wait | saw: the flood STOPPED within ~3 s: riders 0, bodies 1, fps back to 150-285, physics_ms 0.4
BUG (039-046, the big one): the NaN flood ('Offset is non-finite at sample_baked (curve.cpp:556)' errors + 'Vector2 cannot be normalized' warnings, 21 million lines in godot.log, fps 2-6, physics_ms ~60) ran from step 40 to 45 and survived an F5/F9 reload and removing every ore source. It ended only when I deleted the two track rails holding 2 riders. Trigger: raw iron ore landing on track rail R1, which I had laid almost flat (1.1 deg), next to its start stop; riders came to rest there. Session 2's flood also began with iron resting on a rail. Points at the track net (a rider at rest / against the start stop on a near-flat rail getting a NaN s or v) rather than at ore physics.
047 | doing: re-lay R2 (1476,288)->(1508,290) and R1 (1272,272)->(1476,288) at 4.5 deg; re-place iron tapper on (91,24) aimed 40 deg / 555 px/s | saw: all placed (19 pieces), first iron in flight
048-049 | doing: re-aim iron to 42 deg / 590 px/s, watch 4 s | saw: iron still comes down onto R1 (riders 2) and one ore sits against R1's start stop at (1278,267): the NaN precondition again. The 48 px hall (ceiling 240, R1 at 272-288) leaves no arc that clears R1 and still drops into the Beam
050 | doing: RMB iron tapper, try to walk west | saw: NaN flood is back (24.5M warnings, fps 3, physics_ms 40-76); it began right at the end of step 49 with 2 riders on R1 and the iron ore sitting at R1's start stop next to the ingot tap's spout. Player could not move (3 fps)
051-052 | doing: RMB R2 and R1, wait 8 s | saw: this time the flood outlives the rails: riders 0, loose_ore 1 (invisible: NaN position), fps 4
053 | doing: wait 15 s | saw: flood ended when the invisible NaN ore's lifetime ran out (fps 114, loose 0). So the bad body is a loose physics ore that ends up at a NaN position, coming off the rail area
054-055 | doing: walk/hop west through the pit and up the stair cut | saw: holding A+Space stalls at the first step; a rhythm of A then A+Space taps climbs ~130 px/step-command; now (1020,205)
056 | doing: keep climbing | saw: at the top of the stair cut (892,141), copper vein (49-50,9-11) visible to the left inside the ironstone band
057-058 | doing: hop to x798 above the vein, click-mine (50,7),(50,8) | saw: copper (50,9) top face open to the stair cut
059-061 | doing: walk back down the stair cut to (1091,237) so the vein, the pit and the hall are all on one screen | saw: all three beam taps now have their spouts on the RIGHT
BUG (061, step_061.png): a beam tap's side is lost on load. save.json stores side -1.0 for my two left taps, but after F9 beam_tap._attach() recomputes side = (x >= beam.x ? 1 : -1), and since it had snapped x onto the Beam's x, the answer is always right. Since the step-43 reload my copper and iron taps were throwing raw ore RIGHT into the hall, onto R1 by the ingot tap's spout. That's where the raw iron on R1 and the second NaN flood came from (047-050), not the tapper aim.
062 | doing: RMB both left taps, re-place them left of the Beam (copper y234, iron y198) | saw: spouts left again
063 | doing: lay R2, R1 (hall, as before) and stair rails S1 (832,116)->(1016,208), S2 ->(1136,268) feeding FRp | saw: all placed, 20 pieces; the stair rail sits 4 px over the step corners
064 | doing: place copper tapper on (50,9), select, drag aim ~60 deg right / 150 px/s onto S1, Escape | saw: copper ore riding S1 down the stair cut within 3 s
065-067 | doing: watch the copper arrive (10.5 s) | saw: copper rides S1/S2 fine and is handed to FRp, but the Beam gauge stays at usage 0.0, waiting 0. Nothing rises. A piece sits still right of the column at the hall floor under R1's start (1268,280); loose_ore stays 3-4
DESIGN/BUG (065-067): the stair rail delivers copper at ~400 px/s (26 deg, 350 px of track) and the Beam's pull (velocity lerp 5*delta, ~8%/frame) can't catch a piece crossing its 26 px column in 4 frames, so the copper rolls straight through into the hall. Nothing at tier 0 slows a piece down (the brake rail is cut, a track has no brake, a furnace rail is physics with almost no friction), and the Beam's foot is open on the hall side, so a Beam fed by rail from the surface vein can't work as laid out.
068 | doing: RMB the copper tapper to save the rest of the vein for later | saw: removed (about 10 of 24 copper spent, none lifted)
069 | doing: place a spare assembler B (1303,288) on the hall floor right of the Beam's foot as a bumper (R1's riders pass through it, physics pieces bounce off its cabinet back into the column) | saw: placed; the stuck glowing piece still sits under R1's start (1268,280)
070-071 | doing: re-place + re-aim the copper tapper, watch 9.5 s | saw: still usage 0; player ore=4: I was standing on the stair rail and my body was picking the copper RIDERS off the track as they passed. The first test (065-067) was spoiled the same way
072 | doing: walk right out of the stair cut | saw: stopped at (1276,269) between the Beam's foot and bumper B (assemblers block the player too), i.e. in the copper's path again. Copper vein must be almost empty by now (~21 shots across the two placements)
073 | doing: try to hop over B | saw: can't: B's funnel reaches the 48 px hall's ceiling, so an assembler in the hall walls it off for the player
074 | doing: RMB bumper B, walk right | saw: B removed, player in the depression (1383,285); a THIRD NaN flood is running (33M warning lines, fps 4, physics_ms ~32)
BUG (073, step_073.png): third NaN flood. perf.csv shows it starting at the very beginning of step 73 (fine at the end of 072). At that moment I was standing in the Beam's foot right of the column, against B, beside R1's start stop, where a glowing piece (ingot?) had been stuck motionless at (1268,280) since step 65, and my carried ore dropped from 4 to 1 during that step. All three floods start with a piece wedged at track rail R1's start stop beside the ingot tap's spout and the Beam's foot.
075 | doing: wait 15 s | saw: flood over when the NaN ore expired (fps 84-143, loose 0)
076 | doing: F5 | saw: saved, 21 pieces (save.json 12:35)
BUG (076, from save.json): assemblers and labs sink one tile into the floor on every load. My G was placed at y384, F at 448, lab at 496. After one F9 the save holds 400 / 464 / 512, and session 2's surface G went 96 -> 128 over two loads. _snap_to_floor() (assembler.gd, lab.gd) starts from local_to_map(saved y). The saved y is the floor line, so that cell is already the solid floor tile, and the piece is re-seated 16 px lower each load. Tappers don't drift (they save the face above their cell).

== END OF SESSION at step 76 ==
Goal not reached. Techs: none. Flasks made: 0. game_s ~357. Saved with F5 at step 76 (run slot).
Factory state (all in save.json; tile = (col,row), 16 px):
- Main cavern line (fits the 48/60/71 rule on natural ledges plus 4 dug tiles): G = Gear assembler on (97,24) [placed y384, now saved 400 after the sinking bug]; F = Science flask on iron (102,28) [448 -> 464]; lab, researching Processing, in a pit at cols 104-106 [496 -> 512]. Shelf tiles (95,18),(96,18) dug so ingots can drop into G from the hall.
- At the Beam: ingot tap RIGHT y266 (filter ingot); copper tap LEFT y235 and iron tap LEFT y199 (they throw raw ore back onto FRp so dwell adds up until it smelts); furnace rail FRp (1137,273)->(1236,288) from the stair step down into the Beam's foot. Track rails R1 (1273,273)->(1477,289) and R2 ->(1509,291) carry ingots from the ingot tap along the hall to drop into G.
- West: copper tapper on (50,9) (vein about empty, ~22 of 24 shot), stair rails S1 (833,117)->(1017,209), S2 ->(1137,269) down the stair cut to FRp.
- Iron: a 3-wide channel dug from iron vein (91,24) (6 cells, ~36 ore, part used) up to the hall; its tapper was removed (vein keeps its ore).
- Session-2 leftovers on the surface (old G/F/rails, 4 spent tappers) are unused.
What happened: the line downstream of the Beam is built and the pit smelting loop made at least one iron ingot that the ingot tap threw onto R1 (step 41). But (1) three NaN floods (steps 40-45, 49-53, 73-75) each took the game to 2-6 fps; (2) the F9 at step 43 silently turned both left taps to face right, so raw iron got thrown onto R1; (3) the copper run from the west vein never got lifted: my body was picking the riders off the stair rail, and fast pieces cross the Beam's column anyway. The west copper is now nearly gone, and with it every shallow copper on the map.
Plan for next session:
1. After F9: RMB and re-place the two LEFT taps (the side bug flips them right), copper at y~235, iron at y~199, with the spout to the left. Check G/F/lab heights (sinking bug); if G's funnel is now under the shelf, dig (97,18) too.
2. Never stand on a rail or in a tapper's line of fire. Watch from the depression (1340,301) or the cavern.
3. Copper: the shallow vein is spent. Deep copper is the only source: nearest reachable veins are (67-68,44-45), (63-64,47-48), (68-69,48), (75-76,49-50) at y 704-800, under stone (diggable), but below an ironstone layer at rows 38-40 east of col 75; cols 60-74 look open. A tapper lob up a shaft (max 1400 px/s ~ 1000 px high) into the stair-cut/pit area is the only tier-0 lift.
4. Feed the Beam slowly: pieces must reach the foot below ~150 px/s. Ideas: end the feed rail high against the pit's right wall above the hall (rows <=14) so pieces drop down the wall inside the column, or put a solid bumper right of the foot (an assembler blocks the 48 px hall for the player, so dig the hall higher first).
5. Iron: re-place the tapper on (91,24) only once R1 can't catch raw iron (aim apex ~250 at x~1290); otherwise iron lands on R1 by the tap.
Findings so far, ranked:
1. BUG/PERF: NaN flood ('Offset is non-finite at sample_baked (curve.cpp:556)' + 'Vector2 cannot be normalized', up to 33 million log lines, fps 2-6, physics_ms 30-76) happened 3 times. Each time a piece sat wedged at track rail R1's start stop beside the ingot tap's spout at the Beam's foot (first time 2 raw iron riders resting on a 1.1 deg R1). It survives F5/F9; it ends when that loose ore's lifetime runs out (or when the rails are deleted). Session 2's flood also started with iron resting on a rail.
2. BUG: beam_tap side is not restored on load: _attach() recomputes side from x >= beam.x after snapping x to the beam, so every left tap comes back facing right (save.json has side -1).
3. BUG: assemblers and labs sink 16 px into the floor on every load (_snap_to_floor starts from the floor tile itself).
4. DESIGN (copper): only 24 shallow copper on the map (one vein), and tier 1 needs 60. A tier-1 run is impossible without a deep-copper expedition, and tier 0 has no lift for it but a tapper lob. Processing (gear stamp: gear from 1 iron ingot) halves copper per flask and should probably be the forced first research.
5. DESIGN (no buffer): tappers fire 0.71/s, unpowered G takes 5.1 s a gear, and F gets copper only from G's random sideways spit, so each early flask costs ~3 copper and anything above ~0.3 Cu/s is wasted. Removing and re-placing the tapper is the only throttle.
6. DESIGN/BUG (Beam intake): fast pieces (rail-fed ~400 px/s) cross the 26 px column in a few frames and aren't lifted (usage 0.0). The foot is open on the hall side and tier 0 has no way to slow a piece.
7. DESIGN (geometry): fixed tap ejection (150 px/s), the assembler's fixed right-hand spout and pick-proof ironstone/ore leave next to no legal spots for a G->F->lab staircase near the Beam. The one that works is ~400 px away in the cavern and still needed 4 dug tiles. Planning it needed the save file's tile map.
8. DESIGN (feel): standing in a tapper's arc or on a rail silently eats the ore into your gun ammo; an assembler in the 48 px hall walls the player off; movement/climbing cost ~20 of 76 steps (stairs need a hop rhythm; the hook works well).
9. DESIGN (UI): 30 px spacing applies to a rail's start point too and fails silently (R1 refused twice); camera y offset of a few px between steps makes precise clicks drift; RMB only finds a piece near its origin.
10. Carried: assembler held-item pips drawn under its own sprite (still can't see what G/F hold); tapper starts firing at its default aim before you can aim it.
