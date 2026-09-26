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
