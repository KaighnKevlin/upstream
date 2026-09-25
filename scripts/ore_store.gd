extends RefCounted
## Shared by containers that hold ore physically (drop hopper, funnel turret).
##
## Loose ore doesn't collide with other ore (cheap). Inside a container it
## does, so a load stacks up instead of overlapping. On the way in it loses
## its bounce and gets a low-friction "flowing" material, so it runs down
## funnel slopes into the gaps like grain instead of wedging.
##
## A piece that has been still, and is resting on something, for SETTLE_TIME
## is frozen: a frozen pile costs nothing but stays solid to land on. Any
## change to the container (a piece arriving, one leaving) wakes the whole
## pile so it re-settles around the change, then it freezes again. So piles
## never hang in mid-air when the bottom is taken out.

const SETTLE_TIME := 0.4
const SETTLE_SPEED := 8.0
const SETTLE_SPIN := 1.5
const ENTRY_SPEED := 320.0
static var _flow := _make_flow()


static func _make_flow() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.0
	m.friction = 0.35
	return m


static func on(body: Node2D, store: Area2D) -> void:
	if not body is RigidBody2D:
		return
	var b := body as RigidBody2D
	if not b.has_meta("store_material"):
		b.set_meta("store_material", b.physics_material_override)
		b.set_meta("store_z", b.z_index)
	b.physics_material_override = _flow
	b.collision_mask |= 2
	b.angular_damp = 4.0
	b.linear_damp = 1.0
	b.z_index = 0  # inside the cage: behind the front bars (z 1)
	b.linear_velocity = b.linear_velocity.limit_length(ENTRY_SPEED)
	b.set_meta("still_for", 0.0)
	wake_all(store)


static func off(body: Node2D, store: Area2D) -> void:
	if not body is RigidBody2D:
		return
	var b := body as RigidBody2D
	release(b)
	if b.has_meta("store_material"):
		b.physics_material_override = b.get_meta("store_material")
		b.z_index = b.get_meta("store_z", 1)
		b.remove_meta("store_material")
		b.remove_meta("store_z")
	b.collision_mask &= ~2
	b.angular_damp = 0.15 if b.get("kind") == "gear" else 1.5
	b.linear_damp = 0.0
	wake_all(store)


## Unfreeze one stored piece.
static func release(b: RigidBody2D) -> void:
	if b.freeze:
		b.freeze = false
	b.sleeping = false
	b.set_meta("still_for", 0.0)


## Something changed: let the whole pile move again.
static func wake_all(store: Area2D) -> void:
	if store == null or not is_instance_valid(store):
		return
	for body in store.get_overlapping_bodies():
		if body is RigidBody2D:
			release(body)


## Shake the pile a little (a firing turret rattles its magazine), which
## breaks up pieces wedged across a funnel neck.
static func rattle(store: Area2D, strength := 30.0) -> void:
	for body in store.get_overlapping_bodies():
		if body is RigidBody2D:
			release(body)
			body.linear_velocity += Vector2(randf_range(-strength, strength), -strength * 0.4)


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
		var resting := b.linear_velocity.length() < SETTLE_SPEED \
				and absf(b.angular_velocity) < SETTLE_SPIN and b.get_contact_count() > 0
		if resting:
			var t: float = b.get_meta("still_for", 0.0) + delta
			b.set_meta("still_for", t)
			if t >= SETTLE_TIME:
				b.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				b.freeze = true
		else:
			b.set_meta("still_for", 0.0)
