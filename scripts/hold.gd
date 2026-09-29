extends RefCounted
## Who is holding a piece. Shared by every piece that grabs ore/ingots and
## steers them kinematically (gravity off, velocity set toward a target each
## physics frame): mine cart, balloon lift, bowl feeder, magnet rail, sling ...
##
## Without it two holders can both take the same piece and fight over its
## velocity every frame, and whichever lets go first switches gravity back on
## under the other. The convention:
##
##   Hold.free_to_take(o, self)  before grabbing: nobody else has it
##   Hold.claim(o, self)         on grabbing, and again every frame it's held
##   Hold.release(o, self)       on letting go (gravity back on)
##
## A claim names its owner and the physics frame it was last renewed. It
## lapses if the owner is freed, or stops renewing it for STALE frames (a
## holder removed mid-carry, or one that dropped a piece without releasing
## it), so a piece is never stuck as "held" by nobody. Carriers that use the
## older "caught_by" meta (player, drone, magpie, arm, catapult, tube,
## gravity wheel) count as holders too.

const META := "held_by"
const STALE := 3


## The live holder of `o` (a "held_by" claim still being renewed, or a
## "caught_by" carrier still in the tree), or null.
static func holder(o) -> Object:
	if o.has_meta("caught_by"):
		var c = o.get_meta("caught_by")
		if is_instance_valid(c):
			return c
	if held(o):
		return instance_from_id(o.get_meta(META)[0])
	return null


## True if a holder (not a "caught_by" carrier) has `o` right now. For the
## carriers, which keep their own caught_by checks: don't snatch from these.
static func held(o) -> bool:
	if not o.has_meta(META):
		return false
	var h: Array = o.get_meta(META)
	var w = instance_from_id(h[0])
	return w != null and is_instance_valid(w) and Engine.get_physics_frames() - int(h[1]) <= STALE


## True if `owner` may take `o`: it's a live piece not being freed, and
## nobody else is holding it.
static func free_to_take(o, owner: Object) -> bool:
	if not is_instance_valid(o) or o.is_queued_for_deletion():
		return false
	var h := holder(o)
	return h == null or h == owner


## Take `o` for `owner`, or renew the claim. False (and nothing changed) if
## someone else holds it.
static func claim(o, owner: Object) -> bool:
	if not free_to_take(o, owner):
		return false
	o.set_meta(META, [owner.get_instance_id(), Engine.get_physics_frames()])
	return true


## `owner` lets go of `o`: the claim is cleared and gravity comes back on.
## Does nothing if `o` isn't `owner`'s (someone else's hold is left alone).
static func release(o, owner: Object) -> void:
	if not is_instance_valid(o):
		return
	var h := holder(o)
	if h != null and h != owner:
		return
	if o.has_meta(META):
		o.remove_meta(META)
	o.gravity_scale = 1.0


## A claim whose holder is gone or stopped renewing it: clear it and put the
## piece's gravity back (the holder had switched it off). Called by the piece.
static func lapse(o) -> void:
	if o.has_meta(META) and not held(o):
		o.remove_meta(META)
		o.gravity_scale = 1.0
