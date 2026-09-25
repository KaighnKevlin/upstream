extends RefCounted
## Mechanical power. Gravity wheels (group "power_wheels") drive machines
## (group "power_users") within REACH over leather drive belts. A machine's
## power is 0..1: the best of the wheels that reach it. Unpowered machines
## still run, slowly (UNPOWERED); powered, they run at full rate.

const REACH := 190.0
const UNPOWERED := 0.35


## 0..1 at a point: the strongest wheel in reach.
static func level_at(tree: SceneTree, pos: Vector2) -> float:
	var best := 0.0
	for w in tree.get_nodes_in_group("power_wheels"):
		if is_instance_valid(w) and w.global_position.distance_to(pos) <= REACH:
			best = maxf(best, w.power())
	return best


## A machine's rate multiplier: UNPOWERED .. 1.
static func rate_at(tree: SceneTree, pos: Vector2) -> float:
	return lerpf(UNPOWERED, 1.0, level_at(tree, pos))
