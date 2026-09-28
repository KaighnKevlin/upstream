extends RefCounted
## Mechanical power. Gravity wheels (group "power_wheels") drive machines
## (group "power_users") within REACH over leather drive belts. A machine's
## power is 0..1: the best of the wheels that reach it. Unpowered machines
## still run, slowly (UNPOWERED); powered, they run at full rate.
## Rust mites (scenes/rust_mite.gd, group "rust_mites") clinging to a wheel
## or a machine each take MITE_DRAIN of its power away.

const REACH := 190.0
const UNPOWERED := 0.35
const MITE_DRAIN := 0.2        # each clinging mite keeps this share of the power back


## 0..1 at a point: the strongest wheel in reach.
static func level_at(tree: SceneTree, pos: Vector2) -> float:
	var best := 0.0
	for w in tree.get_nodes_in_group("power_wheels"):
		if is_instance_valid(w) and w.global_position.distance_to(pos) <= REACH:
			best = maxf(best, w.power() * drain_at(tree, w.global_position))
	return best * drain_at(tree, pos)


## What rust mites clinging to the piece at `pos` leave of its power: 1 with
## none, less for each one.
static func drain_at(tree: SceneTree, pos: Vector2) -> float:
	var k := 1.0
	for m in tree.get_nodes_in_group("rust_mites"):
		var on = m.clinging_to
		if is_instance_valid(on) and on.global_position.distance_to(pos) < 2.0:
			k *= 1.0 - MITE_DRAIN
	return k


## A machine's rate multiplier: UNPOWERED .. 1.
static func rate_at(tree: SceneTree, pos: Vector2) -> float:
	return lerpf(UNPOWERED, 1.0, level_at(tree, pos))
