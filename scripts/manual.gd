extends CanvasLayer
## The field manual (F1): what every building, enemy, item and event does,
## one line each, in tabs (buildings grouped like the build bar's tabs). F1, Esc or a click outside closes it.

const PixelFont = preload("res://scripts/pixel_font.gd")
const SFX = preload("res://scripts/sfx.gd")

const TEXT := Color(0.95, 0.88, 0.7)
const DIM := Color(0.72, 0.66, 0.52)
const KEYC := Color(0.55, 0.88, 0.92)

const TABS := [
	["TRANSPORT + PRODUCTION", [
		["#", "TRANSPORT", ""],
		["1", "Trampoline", "bounces anything that lands on it; drag its handle to set angle and force"],
		["", "Deflector plate", "flying ore ricochets off it: bank a shot round a corner or into a funnel; click: turn 15 deg"],
		["", "Catch net", "flying ore lands soft, rolls to its ring and drops straight down at one exact point"],
		["9", "Chute", "drag top to bottom: a sloped rail that ore slides down"],
		["", "Brake rail", "drag like a chute: brushes hold what runs on it to 80/150/250 px/s; click its number"],
		["C", "Conveyor belt", "drag out: carries items along; faster when powered"],
		["", "Pneumatic tube", "drag funnel to nozzle: sucks items in and shoots them out, any way"],
		["0", "Splitter", "alternates items left and right; click for left/right only"],
		["8", "Catapult", "catches items in its bucket and lobs them; drag to aim; wired to a trigger it waits for it"],
		["", "Seesaw", "drop something heavy on one end to fling what sits on the other"],
		["4", "Upstream lift", "carries items up; build on its top to extend; click the cap to spill"],
		["V", "Bellows fan", "an aimed air stream that carries light items and buffets fliers"],
		["", "Lantern", "light for the caves: hangs under a ceiling or stands on a pole; clears the fog around it"],
		["#", "PRODUCTION", ""],
		["2", "Vein tapper", "on a dug-out ore block: flings copper or iron ore; drag to aim"],
		["", "Steam borer", "tunnels on its own (click: right, left, down); spits out ore it cuts, even through ironstone"],
		["3", "Laser smelter", "ore flying through the beam melts into an ingot"],
		["", "Furnace rail", "drag like a chute: ore that lingers on it comes off as ingots; lay it shallow, or brake first"],
		["", "Grindstone", "in line with a run: ore rolled into its bed comes out as 3 grit; click: turn it round"],
		["", "Pellet press", "every 3 grit dropped in its hopper is pressed into 1 iron shot; click: turn it round"],
		["", "Gear stamp", "an iron ingot landing on its anvil is stamped into a gear; click: turn it round"],
		["N", "Gravity wheel", "falling ore turns it; powers machines nearby"],
		["", "Paddle wheel", "set in a falling stream: the stream turns it and passes on; powers machines nearby"],
		["", "Treadwheel", "stand in it and walk: power by hand for machines nearby; jump to get out"],
		["", "Flywheel", "by a gravity wheel: stores its surplus, keeps machines running when the feed stops"],
		["", "Steam engine", "burns ore dropped in its funnel; while lit, full power to machines in reach"],
		["T", "Assembler", "ingots into shot, gears, flasks, springs, shells; 3 scrap into a flask; click: recipe"],
		["R", "Crusher", "grinds ore to grit; chews anything standing on its rollers"],
		["Y", "Research lab", "feed it science flasks; click it for the research screen"],
		["", "Drone dock", "two porter drones tidy loose pieces nearby: ingots to the dome, ore to the nearest funnel turret"],
	]],
	["DEFENCE + TRAPS", [
		["#", "DEFENCE", ""],
		["", "Brass sentry", "your own clockwork guard: patrols, hammers walkers; winds down when worn out, an ingot rewinds it"],
		["6", "Funnel turret", "fires whatever ore you feed it at enemies in range"],
		["", "Marble cannon", "feed its hopper: fires flat at walkers in front; copper glances off shields, iron punches through"],
		["", "Trebuchet", "ore in its box is the power, ore in its sling the shot; a trigger or click looses it"],
		["", "Bowling ramp", "ore fed in the top rolls out fast along the floor: iron bowls walkers over, copper just bumps"],
		["", "Grapeshot mortar", "holds 8 pieces; a trigger or click lobs the whole load in a spread onto the nearest walker"],
		["U", "Tesla coil", "fed ingots: chain lightning, reaches through rock"],
		["", "Harpoon ballista", "anti-air, fed scrap or iron ingots: hooks fliers and drags them down"],
		["I", "Flame turret", "burns ore as fuel; sets packs alight and smelts ore in flight"],
		["5", "Drop hopper", "holds ore and dumps it on enemies walking underneath"],
		["Z", "Electromagnet", "pulses: lifts iron and light walkers, then slams them down"],
		["", "Powder keg", "big blast + crater: shoot it, hit it with fast ore, chain it; walkers light its fuse"],
		["#", "TRAPS AND TRIGGERS", ""],
		["", "(triggers trip)", "kegs, trapdoors, pendulums, hoppers, coils, fans, catapults, barricades, dominoes, marble pieces"],
		["7", "Spikes", "hurt anything that falls or walks onto them"],
		["", "Snare", "bear trap: holds a walker for 3 s (titans 1.5 s); flips ore that lands on it"],
		["", "Ball-bearing mat", "lay it on the walkers' path and keep loose ore in it: they skid and slip across"],
		["", "Stamp press", "each ore in its hopper lifts the weight once; it drops on the walker beneath; faster powered"],
		["X", "Trapdoor", "turf over a pit: drops walkers in; bridgers and masons don't see it"],
		["B", "Bumper", "kicks items and enemies away hard"],
		["M", "Wrecking pendulum", "ore knocks it swinging; it smashes walkers"],
		["", "Tripwire", "drag stake to stake: a walker breaking it trips the machines near either stake"],
		["", "Pressure plate", "ore, walkers or you pressing it trip the machines near it"],
		["", "Clockwork timer", "trips the machines near it every 2/4/8 s (click to change)"],
		["", "Pop-up barricade", "hidden in the ground; a trigger nearby makes it spring up 3 tiles for 4 s, then it sinks"],
		["", "Domino row", "drag out a row of slabs; knock the first and they fall in a chain; a trigger flicks it or resets it"],
	]],
	["MARBLE", [
		["#", "THE MARBLE MACHINE", ""],
		["", "Ore is marbles", "ore, grit, shot and ingots all roll; loose ore passes through ore, so lines never back up"],
		["", "Sorting", "by weight: flap sorter, weigh scale, trampoline + deflector; by kind: magnet drum, kicker"],
		["", "Power", "gravity, paddle and tread wheels drive machines in reach; a flywheel stores the surplus"],
		["", "Pacing", "escapement: one per beat; tipping bucket, volcano: batches; silo: a steady feed"],
		["", "Signals", "tally wheel, load cell, bell, plate, tripwire fire what's at their pull-wire's end (or around them, unwired)"],
		["", "What they fire", "points, sluices, flippers, drawbridges, kickers, mortars, silos, and the traps"],
		["#", "MARBLE", ""],
		["", "Beam tap", "on the Beam: pulls rising pieces of one kind out sideways; click: copper/iron/scrap/grit/ingots/any"],
		["", "Banked turn", "at a chute's end: a U-turn corner, out the other way a level down, keeping its speed"],
		["", "Weigh scale", "heavy pieces roll off one side, light ones the other; click: tip weight 1.5 / 2.5"],
		["", "Flap sorter", "drag like a chute: a piece heavier than a flap's spring drops through; click a flap: spring"],
		["", "Magnet drum", "where a chute ends: iron things cling and drop behind it; copper and stone fly on"],
		["", "Tipping bucket", "fills one marble at a time, then pours the whole batch at once; click: 3/5/8"],
		["", "Sieve rail", "drag like a chute: grit drops through its rungs, bigger pieces roll on"],
		["", "Felt chute", "drag like a chute: marbles on it make no noise, but the felt slows them"],
		["", "Crossover", "two streams cross in an X, each keeping its own line; feed its top corners"],
		["", "Trommel", "drag from its mouth: grit drops out the holes, the rest rolls out the end; faster powered"],
		["", "Dice box", "drop a stream in: each piece out a random side (2 or 3 ways: click); fair over a long run, never a pattern"],
		["", "Flow meter", "over a chute: reads pieces a minute going by (last 10 s); click for all / copper / iron; touches nothing"],
		["", "Check valve", "a flap across a track: through the way its arrow points, a wall the other way; click: turn it"],
		["", "Flume", "level water trough (drag): copper and grit float over the weir on the current; iron, shot and gears sink and pile up until a trigger or click flushes them"],
		["", "Magnet rail", "overhead bar (drag): iron that comes up under it clings and rides to the far end, faster downhill; copper falls through"],
		["", "Pop bumper", "pinball post: kicks whatever touches it away, harder than it came; a few make a mixer"],
		["", "Jump", "flicks pieces across a gap; drag to set the landing; slow ones drop short (sorts by speed)"],
		["", "Loop-the-loop", "a hoop on a rail: fast marbles go round and on, slow ones fall off; feed it off a steep drop"],
		["", "Teeter launcher", "a piece dropped in its high cup flings the one waiting in the low cup up"],
		["", "Gauss cannon", "roll a piece into its magnet end: it shoots the waiting one out the far end, faster"],
		["", "Tiptube", "at a chute's end: a piece tips it over and pours out the other way, a level down"],
		["", "Hammer", "a drop on its paddle swings the head into the piece on its ledge and launches it"],
		["", "Volcano", "collects 3/5 (click), then erupts them all straight up; a trigger fires it early"],
		["", "Helix", "a corkscrew: down 2/3/4 levels (click) in one column, out at a steady speed"],
	]],
	["LIFTS + LOGIC", [
		["#", "LIFTS", ""],
		["", "Booster rail", "drag the way it drives: rollers push pieces along, uphill too; full speed when powered"],
		["", "Counterweight lift", "drop heavy in the top bucket: once it outweighs the bottom one, that load rides up"],
		["", "Ropeway", "drag high post to low: ore dropped on the high landing zips across overhead"],
		["", "Mine cart", "drag loading end to tipping end: fills with 3/5/8 (click), runs across, tips, winched back"],
		["", "Archimedes screw", "drag bottom to top: carries pieces rolled into its mouth up; faster powered"],
		["", "Robotic arm", "picks matching pieces off one spot, drops them at another; click the base: filter"],
		["", "Stair lift", "bobbing brass steps hop marbles up one at a time; faster powered"],
		["", "Ferris lift", "cups scoop marbles at the bottom and tip them out at the top; faster powered"],
		["", "Plunger", "click and hold, let go: fires a marble straight up; reloads what falls back in"],
		["", "Vortex funnel", "marbles rolled in over the rim spiral down and drop out one at a time"],
		["", "Chime bar", "drag a sloped bar: a marble landing on it rings its note; click: retune"],
		["", "Dispenser", "drops a fresh marble every 1/2/4 s (click)"],
		["", "Silo", "stores up to 40 dropped in its funnel; lets them out every 0.5/1/2 s or one per trigger (click)"],
		["", "Goal cup", "counts marbles in; when full it chimes and fires the traps in reach"],
		["", "Transfer arm", "catches a piece in its low cup and swings it over onto the level above; faster powered"],
		["#", "LOGIC", ""],
		["", "Flip-flop", "sends every other marble each way, by gravity alone"],
		["", "Rotary distributor", "drop a stream in: out left, down, right in turn; click to skip one"],
		["", "Points switch", "a rocker that stays put until a trigger or a click throws it"],
		["", "Pair gate", "AND: holds each side's pieces; lets one from each go together only when both have one"],
		["", "Overflow gate", "feeds its first side until the spot it watches is full, then the other; drag the ring there"],
		["", "Kicker", "over a chute: punches every iron/copper/scrap (click) out of the line, or on a trigger"],
		["", "Escapement", "at a track's end: lets one marble through per beat; click: 0.6/1.2/2.4 s"],
		["", "Tally wheel", "over a chute: every 3/5/10 pieces (click) fires the traps at its wire's end (drag it)"],
		["", "Load cell", "when the ore in its pan weighs 2/5/10 (click), fires the traps at its wire's end (drag it)"],
		["", "Spinner", "vane hung just over a track: pieces rolling under spin it (and lose a little speed); powers machines in reach"],
		["", "Rope bridge", "drag post to post: walkers, you and pieces cross; a trigger or a click on the near post cuts it, dropping what's on it; knits back in 5 s"],
		["", "Flail", "post with a spiked ball on a chain: a wheel in reach whirls it, battering walkers and knocking them back; it only lolls round unpowered"],
		["", "Gabion", "wire cage on the ground: pieces dropped in build a wall (12 = full); walkers stop and hack pieces out; a feed mends it"],
		["", "Igniter", "brazier over a track: lights what rolls under it; it bursts on a walker, or when its fuse (1/2/3 s, click) runs out"],
		["", "Balloon lift", "pieces in its basket float straight up to the pin (80/160/240/320 px, click the bottle) and are tossed off toward the flag: lifts through open air"],
		["", "Sling", "whirligig: catches a piece, whirls it twice, throws it where the arrow points (click the hub); twice as hard powered"],
		["", "Speed trap", "over a line: fires its wire for pieces faster than 150/250/350 (click); shows the last speed"],
		["", "Sluice gate", "across a chute: holds the stream back until a trigger or a click lets the backlog go"],
		["", "Flipper", "pieces rest on it; a trigger or a click bats them high"],
		["", "Bell", "a marble strikes it: it rings and fires the traps in reach"],
		["", "Drawbridge", "lowered, pieces cross the gap; raised, they drop in; a trigger or a click swings it"],
	]],
	["ENEMIES", [
		["", "Titan", "slow, tough axe-wielder; leaps out of ditches; stomps"],
		["", "Scuttler", "fast beetle that crawls up walls and blows itself up on the dome"],
		["", "Soldier", "spear automaton; plants siege ladders at ditches"],
		["", "Shieldbearer", "tower shield turns light ore aside from the front; hit it from above"],
		["", "Caster", "hovers at range and shoots bolts"],
		["", "Ornithopter", "flier that drops bombs as it passes"],
		["", "Magpie", "steals loose ore and flies off with it"],
		["", "Sapper", "tunnels under your defences to breach the dome; only lightning reaches it"],
		["", "Bridge engine", "lays a bridge across a ditch for the pack; snap it with iron"],
		["", "Mason", "bricks your ditches in with stone"],
		["", "Cave crawler", "hangs from cave ceilings, drops on you when you walk beneath, bites"],
		["", "The Colossus", "boss, waves 15, 25...: a titan twice the size; strides over ditches, ground-shaking stomp"],
		["", "Roller", "an iron ball that rolls at the dome; stuck in a ditch it plugs it level for the pack: break the plug"],
		["", "Grenadier", "lobs lit bombs that bounce: trampolines, bumpers and fans send them back"],
		["", "Mortar crab", "plants out of reach and lobs shells over your defences at the dome"],
		["", "Gremlin", "saboteur: ignores the dome, unscrews your machines, power first; skips ones it can't reach"],
		["", "Tinker", "fragile repair crew that welds its friends back up: kill it first"],
		["", "Troop airship", "flies over everything and lowers soldiers behind your lines"],
		["", "Foundry Engine", "boss every 5th wave: fireproof; flings slag, spawns scuttlers, bulldozes ditches"],
		["", "Dreadnought", "flying boss every 10th wave: parks over your works, bombs, launches fliers"],
		["", "Gilded", "from wave 6: gold elites with double health and double loot"],
		["", "Magma Wyrm", "mini-boss of the depths: sleeps in a magma pool, burrows through rock after you; hit its head; drops a relic"],
		["", "Cinder bat", "roosts in the hot depths; swoops down to bite, flaps back up to roost"],
		["", "Burrower", "wave 4+: a clockwork mole; digs in from the edge to your machine pieces and chews them apart"],
		["", "Rust mite", "wave 6+, once you have power: a swarm that seeps onto powered machines and drains them"],
	]],
	["ITEMS AND EVENTS", [
		["", "Copper ore", "light and bouncy: the basic ammo and ingot"],
		["", "Iron ore", "heavy: hits harder, punches through shields"],
		["", "Ingots", "smelted ore: into the dome they repair it; tesla charge, assembler input"],
		["", "Iron shot", "dense ammo from the assembler"],
		["", "Springsteel", "ricochets through a whole line of enemies"],
		["", "Blast shell", "explodes on impact; sets off other shells nearby"],
		["", "Gear / flask", "assembler parts; flasks are science for the lab"],
		["", "Grit", "crushed ore: three light chips per ore; shell filling"],
		["", "Scrap", "what's left of a wrecked automaton: melt it, grind it, fire it"],
		["", "Salvage cache", "strongboxes hidden in caves: walk into one for loot"],
		["", "The depths", "the bottom of the world runs hot: magma pools burn, and melt dropped iron/copper ore into ingots"],
		["", "Firedamp", "glowing mine gas in deep caves: chokes you; any spark (shot, blast, bolt) sets off a fireball that chains"],
		["", "Buried vault", "one per world, deep down behind ironstone: destroy its sentinel for a relic (free research)"],
		["", "Ore geyser", "cave vents that erupt ore every 15-25 s; catch the spray"],
		["", "Meteor shower", "burning ore falls from the sky (F6 in sandbox)"],
		["", "Thunderstorm", "lightning seeks tall metal and charges tesla coils (F7)"],
		["", "Gale", "a strong wind: everything in the air drifts downwind; covered runs don't care (F3)"],
		["", "Earthquake", "loose items jump, enemies stumble, cave roofs fall in (F4)"],
		["Shift", "Grappling hook", "reel up walls, yank enemies, drag loot back"],
		["W", "Steam jump", "jump again in mid-air: two boiler bursts, refilled on the ground"],
		["", "Keys", "Tab/wheel: pick a piece  RMB: remove  L: light  F8: music"],
	]],
]

const ROWS := 17   # entries to a column: an entry is two lines, 28 px, in 510 px

var _tab := 0
var _page := 0
var _root: Control


func _ready() -> void:
	layer = 7
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)


func toggle() -> void:
	visible = not visible
	if visible:
		_build()
	SFX.play(self, SFX.sfx_clink())


func _label(text: String, at: Vector2, size: int, color: Color, width: float) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = at
	l.size = Vector2(width, size + 4)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)


func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(80 + i * 190, 58), Vector2(180, 26))


func _page_rect() -> Rect2:
	return Rect2(Vector2(930, 32), Vector2(110, 20))


## Lays a tab's entries out in columns of up to ROWS. A tab with section
## headers starts each section in a column of its own, unless it's too long
## for one anyway and there's room left to start it under the last; a tab
## without splits evenly in two. Two columns to a page; any more go on
## further pages, turned with the page button by the title.
func _columns(entries: Array) -> Array:
	var cols := [[]]
	if entries.is_empty():
		return cols
	if entries[0][0] != "#":
		var per := mini(ROWS, ceili(entries.size() / 2.0))
		for e in entries:
			if cols[-1].size() >= per:
				cols.append([])
			cols[-1].append(e)
		return cols
	var section := ""
	for k in entries.size():
		var e: Array = entries[k]
		if e[0] == "#":
			section = e[1]
			var n := 1   # the section's rows, header included
			while k + n < entries.size() and entries[k + n][0] != "#":
				n += 1
			var room: int = ROWS - cols[-1].size()
			if not cols[-1].is_empty() and (n <= ROWS or room < 4):
				cols.append([])
		elif cols[-1].size() >= ROWS:   # runs on, under its header again
			cols.append([["#", section + " (CONT.)", ""]])
		cols[-1].append(e)
	return cols


func _pages() -> int:
	return maxi(1, ceili(_columns(TABS[_tab][1]).size() / 2.0))


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var p := NinePatchRect.new()
	p.texture = preload("res://assets/ui/panel.png")
	p.patch_margin_left = 8
	p.patch_margin_top = 8
	p.patch_margin_right = 8
	p.patch_margin_bottom = 8
	p.position = Vector2(60, 24)
	p.size = Vector2(1160, 600)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_label("FIELD MANUAL", Vector2(80, 32), 20, TEXT, 400)
	_label("F1 closes", Vector2(1080, 38), 10, DIM, 120)
	for i in TABS.size():
		var r := _tab_rect(i)
		var bg := ColorRect.new()
		bg.position = r.position
		bg.size = r.size
		bg.color = Color(0.52, 0.41, 0.27) if i == _tab else Color(0.2, 0.16, 0.12)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bg)
		_label(TABS[i][0], r.position + Vector2(10, 7), 10, TEXT, r.size.x - 12)
	var all_cols := _columns(TABS[_tab][1])
	var pages := _pages()
	_page = clampi(_page, 0, pages - 1)
	if pages > 1:   # a page turner by the title, like the build bar's page arrow
		var pr := _page_rect()
		var pbg := ColorRect.new()
		pbg.position = pr.position
		pbg.size = pr.size
		pbg.color = Color(0.2, 0.16, 0.12)
		pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(pbg)
		_label("page %d/%d  >" % [_page + 1, pages], pr.position + Vector2(10, 5), 10, KEYC, pr.size.x - 12)
	var cols: Array = all_cols.slice(_page * 2, _page * 2 + 2)
	var most := 1
	for c in cols:
		most = maxi(most, c.size())
	var row_h := minf(40.0, 510.0 / most)
	var placed := []
	for col in cols.size():
		for row in cols[col].size():
			placed.append([col, row, cols[col][row]])
	for pl in placed:
		var col: int = pl[0]
		var row: int = pl[1]
		var e: Array = pl[2]
		var at := Vector2(80 + col * 560, 96 + row * row_h)
		if e[0] == "#":   # a section header, like the build bar's tabs
			_label(e[1], at + Vector2(0, 8), 10, KEYC, 400)
			var rule := ColorRect.new()
			rule.color = Color(0.55, 0.88, 0.92, 0.35)
			rule.position = at + Vector2(0, 24)
			rule.size = Vector2(520, 1)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(rule)
			continue
		if e[0] != "":
			_label(e[0], at, 10, KEYC, 50)
		_label(e[1], at + Vector2(52, 0), 10, TEXT, 200)
		_label(e[2], at + Vector2(52, 14), 10, DIM, 500)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in TABS.size():
			if _tab_rect(i).has_point(event.position):
				_tab = i
				_page = 0
				_build()
				get_viewport().set_input_as_handled()
				return
		if _pages() > 1 and _page_rect().has_point(event.position):
			_page = (_page + 1) % _pages()
			_build()
			get_viewport().set_input_as_handled()
			return
		if not Rect2(Vector2(60, 24), Vector2(1160, 600)).has_point(event.position):
			toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
