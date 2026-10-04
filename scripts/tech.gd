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
	132,  # Track rail
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
		"unlocks": [133, 66, 59],
		"desc": "track splitter, points switch, overflow gate"},
	{"id": "buffers", "name": "Buffers & metering", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [135, 134, 106],
		"desc": "track bin, track escapement, flow meter"},
	{"id": "sorting", "name": "Sorting", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [63, 42],
		"desc": "magnet drum, sieve rail"},
	{"id": "processing", "name": "Processing", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [94, 92, 93],
		"desc": "gear stamp, grindstone, pellet press"},
	{"id": "power_haul", "name": "Power & haul", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [15, 108],
		"desc": "gravity wheel (falling marbles drive machines), mine cart"},
	{"id": "defence_1", "name": "Defence I", "tier": 1, "needs": [], "cost": {"flask": 5},
		"unlocks": [114, 121],
		"desc": "gabion, spring trap"},
	# tier 2: red + clockwork flasks
	{"id": "forging", "name": "Forging", "tier": 2, "needs": ["processing"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [131, 74],
		"desc": "crucible, pair gate"},
	{"id": "trajectory", "name": "Trajectory", "tier": 2, "needs": ["routing"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [47, 62, 69],
		"desc": "jump, catch net, crossover"},
	{"id": "signals", "name": "Signals", "tier": 2, "needs": ["buffers"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [28, 64, 65],
		"desc": "tripwire, sluice gate, tally wheel"},
	{"id": "defence_2", "name": "Defence II", "tier": 2, "needs": ["defence_1"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [130, 126],
		"desc": "flak cannon, caltrop spreader"},
	{"id": "haul_2", "name": "Long haul", "tier": 2, "needs": ["power_haul"], "cost": {"flask": 5, "flask_clock": 5},
		"unlocks": [77],
		"desc": "ropeway"},
	# tier 3: red + clockwork + bronze flasks
	{"id": "beam_optics", "name": "Beam optics", "tier": 3, "needs": ["forging"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [],
		"desc": "the lens: grows the beam (coming)"},
	{"id": "defence_3", "name": "Heavy defence", "tier": 3, "needs": ["defence_2"], "cost": {"flask": 5, "flask_clock": 5, "flask_bronze": 5},
		"unlocks": [90],
		"desc": "grapeshot mortar"},
]

## Not in Factory mode at all (still in the sandbox). The core set is the
## 35 above, by four rules: nothing lifts but the beam, the only power is
## falling marbles (gravity wheel), one piece per job (the track-native one),
## and every defence eats marbles.
const CUT := [
	1,    # Trampoline
	3,    # Laser smelter
	5,    # Drop hopper
	7,    # Spikes
	8,    # Catapult
	9,    # Chute
	10,   # Splitter
	11,   # Bumper
	12,   # Conveyor belt
	13,   # Bellows fan
	14,   # Wrecking pendulum
	18,   # Tesla coil
	19,   # Flame turret
	20,   # Trapdoor
	21,   # Crusher
	22,   # Electromagnet
	23,   # Harpoon ballista
	24,   # Seesaw
	25,   # Pneumatic tube
	26,   # Powder keg
	27,   # Snare
	29,   # Pressure plate
	30,   # Steam borer
	31,   # Lantern
	32,   # Brass sentry
	33,   # Clockwork timer
	34,   # Drone dock
	35,   # Pop-up barricade
	36,   # Steam engine
	37,   # Domino row
	39,   # Flip-flop
	40,   # Escapement
	41,   # Tipping bucket
	43,   # Archimedes screw
	44,   # Robotic arm
	45,   # Stair lift
	46,   # Ferris lift
	48,   # Bell
	49,   # Loop-the-loop
	50,   # Dispenser
	51,   # Goal cup
	52,   # Weigh scale
	53,   # Marble cannon
	54,   # Felt chute
	55,   # Chime bar
	56,   # Plunger
	57,   # Vortex funnel
	58,   # Flap sorter
	60,   # Deflector plate
	61,   # Booster rail
	67,   # Brake rail
	68,   # Teeter launcher
	70,   # Flywheel
	71,   # Rotary distributor
	72,   # Flipper
	73,   # Counterweight lift
	76,   # Silo
	78,   # Load cell
	79,   # Banked turn
	80,   # Gauss cannon
	81,   # Treadwheel
	82,   # Trebuchet
	83,   # Paddle wheel
	84,   # Ball-bearing mat
	85,   # Kicker
	86,   # Tiptube
	87,   # Hammer
	88,   # Volcano
	89,   # Bowling ramp
	91,   # Stamp press
	95,   # Helix
	96,   # Drawbridge
	97,   # Transfer arm
	98,   # Latch
	99,   # Delay relay
	100,  # Relay hub
	101,  # Ground listener
	102,  # Iron plating
	103,  # Steam jet
	104,  # Trommel
	105,  # Dice box
	107,  # Check valve
	109,  # Pop bumper
	110,  # Speed trap
	111,  # Sling
	112,  # Igniter
	113,  # Spinner
	115,  # Magnet rail
	116,  # Rope bridge
	117,  # Balloon lift
	118,  # Flail
	119,  # Flume
	120,  # Wrecking ball
	122,  # Bowl feeder
	123,  # Water wheel
	124,  # Balance
	125,  # Hourglass
	127,  # Panning box
	128,  # Portcullis
	129,  # Fuse cord
	136,  # Track source
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
