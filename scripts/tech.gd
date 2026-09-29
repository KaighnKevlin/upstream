extends RefCounted
## Research. Labs turn science flasks into levels of these techs; machines
## read mult(id) for their upgrade (1.0 with nothing researched). Levels are
## kept in the sandbox save.

const TECHS := [
	{"id": "springs", "name": "Tempered springs", "desc": "trampolines, bumpers +20% kick", "per": 0.2, "max": 3, "cost": 3},
	{"id": "barrels", "name": "Rifled barrels", "desc": "turrets +15% reach, +20% fire rate", "per": 0.15, "max": 3, "cost": 4},
	{"id": "belts", "name": "Greased belts", "desc": "belts +35% speed", "per": 0.35, "max": 3, "cost": 3},
	{"id": "buckets", "name": "Balanced buckets", "desc": "gravity wheels +40% power", "per": 0.4, "max": 2, "cost": 4},
	{"id": "assembly", "name": "Quick assembly", "desc": "assemblers, crushers +40% speed", "per": 0.4, "max": 2, "cost": 4},
	{"id": "lamps", "name": "Carbide lamp", "desc": "your lamp reveals +30% further", "per": 0.3, "max": 2, "cost": 2},
	{"id": "hook", "name": "Longer chain", "desc": "grappling hook +35% reach", "per": 0.35, "max": 2, "cost": 3},
	{"id": "lifts", "name": "Faster current", "desc": "upstream lifts +40% speed", "per": 0.4, "max": 2, "cost": 3},
	{"id": "magnets", "name": "Wound coils", "desc": "electromagnets +25% reach and pull", "per": 0.25, "max": 2, "cost": 4},
	{"id": "grinders", "name": "Hardened rollers", "desc": "crushers chew +50% harder", "per": 0.5, "max": 2, "cost": 4},
	{"id": "harpoons", "name": "Barbed harpoons", "desc": "harpoon winches +50% faster", "per": 0.5, "max": 2, "cost": 4},
	{"id": "charges", "name": "Packed charges", "desc": "blast shells +25% radius and damage", "per": 0.25, "max": 2, "cost": 5},
	{"id": "gunsmith", "name": "Gunsmith", "desc": "your gun: +1 pellet, +15% reach", "per": 0.15, "max": 3, "cost": 3},
	{"id": "boilers", "name": "High-pressure boiler", "desc": "one more steam jump in the air", "per": 0.5, "max": 2, "cost": 3},
]

static var levels := {}


static func level(id: String) -> int:
	return levels.get(id, 0)


static func mult(id: String) -> float:
	for t in TECHS:
		if t.id == id:
			return 1.0 + t.per * level(id)
	return 1.0


static func info(id: String) -> Dictionary:
	for t in TECHS:
		if t.id == id:
			return t
	return {}


static func maxed(id: String) -> bool:
	return level(id) >= int(info(id).get("max", 0))


# ── Factory tech tree (data only: nothing reads it yet) ─────────────────
# Piece ids are BuildSystem.BuildType ints (scripts/build_system.gd). Every
# piece in build_bar PIECES sits in exactly one of START, a TREE tech's
# unlocks, or CUT (tools/scenarios/tech_tree_rec.gd checks it). Tree ids
# share Tech.levels with the upgrade TECHS, so they must not collide.

## Tier 0: what a Factory game starts with.
const START := [
	2,    # Vein tapper
	9,    # Chute
	132,  # Track rail (the chute's track-system successor)
	4,    # Upstream lift
	38,   # Beam tap
	75,   # Furnace rail
	16,   # Assembler
	17,   # Research lab
	6,    # Funnel turret
]

## Unlock techs. cost: science kind -> flasks; needs: tech ids.
const TREE := [
	# tier 1: red flasks
	{"id": "routing", "name": "Routing", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [10, 59, 66, 11, 13, 60, 62, 79, 107, 133],
		"desc": "splitter, overflow gate, points; bumper, bellows, deflector, catch net, banked turn, check valve, track splitter"},
	{"id": "buffers", "name": "Buffers & metering", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [76, 40, 106, 65, 41, 134, 135],
		"desc": "silo, escapement, flow meter, tally wheel; tipping bucket, track escapement, track bin"},
	{"id": "sorting", "name": "Sorting", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [63, 42],
		"desc": "magnet drum, sieve rail"},
	{"id": "processing", "name": "Processing", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [92, 94, 93],
		"desc": "grindstone, gear stamp, pellet press"},
	{"id": "power_haul", "name": "Power & haul", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [15, 113, 108, 1, 77],
		"desc": "gravity wheel, spinner, mine cart, trampoline; ropeway"},
	{"id": "defence_1", "name": "Defence I", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [121, 126, 130, 114, 7, 27, 84, 102, 103, 31],
		"desc": "spring trap, caltrop spreader, flak cannon, gabion; spikes, snare, bearing mat, iron plating, steam jet, lantern"},
	# tier 2: red + clockwork flasks
	{"id": "forging", "name": "Forging", "tier": 2, "needs": ["processing"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [131, 85, 74, 67],
		"desc": "crucible, kicker, pair gate, brake rail"},
	{"id": "signals", "name": "Signals", "tier": 2, "needs": ["buffers"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [28, 29, 98, 78, 64, 33, 20, 72, 96, 101],
		"desc": "tripwire, pressure plate, latch, load cell, sluice; clockwork timer, trapdoor, flipper, drawbridge, ground listener"},
	{"id": "defence_2", "name": "Heavy defence", "tier": 2, "needs": ["defence_1"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [90, 23, 18, 5, 19, 22, 26, 35, 53, 89, 91, 116, 118],
		"desc": "grapeshot mortar, harpoon ballista, tesla coil, drop hopper; flame turret, electromagnet, powder keg, barricade, marble cannon, bowling ramp, stamp press, rope bridge, flail"},
	{"id": "sorting_2", "name": "Sorting II", "tier": 2, "needs": ["sorting", "routing"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [115, 58, 71, 69, 119, 127],
		"desc": "magnet rail, flap sorter, distributor, crossover, flume, panning box"},
	{"id": "power_2", "name": "Power II", "tier": 2, "needs": ["power_haul"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [70, 12, 97],
		"desc": "flywheel, conveyor belt, transfer arm"},
	# tier 3: red + clockwork + bronze flasks
	{"id": "beam_optics", "name": "Beam optics", "tier": 3, "needs": ["forging"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [],
		"desc": "no pieces yet: a flag for later beam work"},
	{"id": "automata", "name": "Automata", "tier": 3, "needs": ["forging", "power_2"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [34, 32, 30],
		"desc": "drone dock, brass sentry, steam borer"},
	{"id": "spectacle", "name": "Spectacle", "tier": 3, "needs": ["power_2"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [117, 49, 47, 8, 122],
		"desc": "balloon lift, loop-the-loop, jump, catapult, bowl feeder"},
	{"id": "clockwork", "name": "Clockwork", "tier": 3, "needs": ["signals"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [99, 100, 125, 124, 129, 110],
		"desc": "delay relay, relay hub, hourglass, balance, fuse cord, speed trap"},
]

## Not in Factory mode at all (still in the sandbox).
const CUT := [
	36,   # Steam engine
	81,   # Treadwheel
	123,  # Water wheel
	50,   # Dispenser
	136,  # Track source
	43,   # Archimedes screw
	45,   # Stair lift
	46,   # Ferris lift
	73,   # Counterweight lift
	56,   # Plunger
	25,   # Pneumatic tube
	61,   # Booster rail
	80,   # Gauss cannon
	111,  # Sling
	44,   # Robotic arm
	82,   # Trebuchet
	39,   # Flip-flop (rocker)
	105,  # Dice box
	104,  # Trommel
	52,   # Weigh scale
	3,    # Laser smelter
	21,   # Crusher
	83,   # Paddle wheel
	120,  # Wrecking ball
	128,  # Portcullis
	112,  # Igniter
	109,  # Pop bumper
	14,   # Wrecking pendulum
	# toys
	55,   # Chime bar
	37,   # Domino row
	51,   # Goal cup
	88,   # Volcano
	95,   # Helix
	86,   # Tiptube
	87,   # Hammer
	68,   # Teeter launcher
	24,   # Seesaw
	57,   # Vortex funnel
	48,   # Bell
	54,   # Felt chute
]

## What makes each kind (BuildType ints), for the reachability check only.
## Ingots are ore of kind copper/iron in group "ingots"; the assembler keys
## them "<kind>_ingot", and so does this.
const MAKES := {
	"copper": [2],
	"iron": [2],
	"copper_ingot": [75, 3],
	"iron_ingot": [75, 3],
	"gear": [16, 94],
	"shot": [93, 16],
	"grit": [92, 21],
	"bronze": [131],
	"flask": [16],
	"flask_clock": [16],
	"flask_bronze": [16],
}


static func researched(id: String) -> bool:
	return int(levels.get(id, 0)) >= 1


static func tree_tech(id: String) -> Dictionary:
	for t in TREE:
		if t.id == id:
			return t
	return {}


static func available(id: String) -> bool:
	var t := tree_tech(id)
	if t.is_empty():
		return false
	for n in t.needs:
		if not researched(n):
			return false
	return true


static func unlocked_types() -> Array:
	var out: Array = START.duplicate()
	for t in TREE:
		if researched(t.id):
			for u in t.unlocks:
				if not out.has(u):
					out.append(u)
	return out


## A tech's cost as kind -> count: an upgrade TECHS entry's int cost is red flasks.
static func cost_of(t: Dictionary) -> Dictionary:
	var c = t.get("cost", 0)
	if c is Dictionary:
		return c
	return {"flask": int(c)}


# ── Factory research (tree techs through a lab) ─────────────────────────

## A science kind as the player reads it.
static func kind_name(kind: String) -> String:
	return {"flask": "red", "flask_clock": "clockwork", "flask_bronze": "bronze"}.get(kind, kind)


## Can anything make this kind yet? (an assembler recipe puts it out)
static func producible(kind: String) -> bool:
	for r in load("res://scenes/assembler.gd").RECIPES:
		if r.out == kind:
			return true
	return false


## A tree tech a lab can take on: its needs are met, it isn't done, and
## every science it costs can be made.
static func researchable(id: String) -> bool:
	if researched(id) or not available(id):
		return false
	for k in cost_of(tree_tech(id)):
		if not producible(k):
			return false
	return true


## A build piece's short name (the build bar's, without its hint).
static func piece_name(id: int) -> String:
	var p = load("res://scripts/build_bar.gd").PIECES.get(id)
	if p == null:
		return str(id)
	return String(p[1]).get_slice(" (", 0)


static func unlock_names(t: Dictionary) -> Array:
	return t.get("unlocks", []).map(func(id): return piece_name(id))


## A tech's name as shown (the pixel font has no "&").
static func title(t: Dictionary) -> String:
	return String(t.get("name", "")).replace("&", "and")


## Text broken into lines of at most n characters, at spaces (the UI's
## labels don't wrap the pixel font reliably).
static func wrap_text(s: String, n: int) -> String:
	var lines := []
	var line := ""
	for w in s.split(" "):
		if line != "" and line.length() + 1 + w.length() > n:
			lines.append(line)
			line = w
		else:
			line = w if line == "" else line + " " + w
	if line != "":
		lines.append(line)
	return "\n".join(lines)
