extends RefCounted
## Shared by containers that hold ore physically (drop hopper, funnel turret).
##
## Loose ore doesn't collide with other ore (cheap). Inside a container it
## does, so a load stacks up instead of overlapping; it also loses its
## bounce and most of its speed on the way in, so it lands and stays. Once a
## piece has been nearly still for SETTLE_TIME it's frozen: a frozen pile
## costs nothing to simulate but is still solid for ore landing on it.

const SETTLE_TIME := 0.3
const SETTLE_SPEED := 12.0
const ENTRY_SPEED := 260.0
static var _dead := _make_dead()


static func _make_dead() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.0
	m.friction = 0.9
	return m


static func on(body: Node2D) -> void:
	if not body is RigidBody2D:
		return
	var b := body as RigidBody2D
	if not b.has_meta("store_material"):
		b.set_meta("store_material", b.physics_material_override)
	b.physics_material_override = _dead
	b.collision_mask |= 2
	b.angular_damp = 8.0
	b.linear_damp = 2.0
	b.linear_velocity = b.linear_velocity.limit_length(ENTRY_SPEED)
	b.set_meta("still_for", 0.0)


static func off(body: Node2D) -> void:
	if not body is RigidBody2D:
		return
	var b := body as RigidBody2D
	release(b)
	if b.has_meta("store_material"):
		b.physics_material_override = b.get_meta("store_material")
		b.remove_meta("store_material")
	b.collision_mask &= ~2
	b.angular_damp = 1.5
	b.linear_damp = 0.0


## Unfreeze a stored piece (before firing it or opening the trapdoor).
static func release(b: RigidBody2D) -> void:
	if b.freeze:
		b.freeze = false
	b.sleeping = false
	b.set_meta("still_for", 0.0)


## Call every physics frame with the container's store area.
static func settle(store: Area2D, delta: float) -> void:
	for body in store.get_overlapping_bodies():
		if not body is RigidBody2D:
			continue
		var b := body as RigidBody2D
		if "_timer" in b:
			b._timer = 0.0  # stored ore doesn't despawn
		if b.freeze:
			continue
		if b.linear_velocity.length() < SETTLE_SPEED:
			var t: float = b.get_meta("still_for", 0.0) + delta
			b.set_meta("still_for", t)
			if t >= SETTLE_TIME:
				b.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				b.freeze = true
		else:
			b.set_meta("still_for", 0.0)
