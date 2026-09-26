extends Node2D
## Electromagnet (Z): a copper-wound drum hanging from a bracket. It pulses:
## on for a spell, off for a spell. While it's on it drags iron things
## (iron ore, shot, springs, gears) up to its face in a clattering clump and
## hauls light clockwork enemies off their feet; when it cuts out,
## everything drops. Enemies dropped from high enough land hard and break
## (fall damage), or land in whatever you put underneath: a pit, spikes, a
## crusher. Titans and bridge engines are too heavy to lift. A gravity
## wheel driving it widens its reach.
## Art: tools/art/gen_magnet.py (2 frames of 36x40: off, on).

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const LightTextures = preload("res://scripts/light_textures.gd")
const Tech = preload("res://scripts/tech.gd")

const FACE := Vector2(0, 32)      # the pull point, from the bracket
const ON_TIME := 1.6
const OFF_TIME := 1.4
const REACH := 105.0              # unpowered; up to +45 when fully driven
const METAL := ["iron", "shot", "spring", "gear", "scrap"]
const PULL := 2600.0              # item acceleration at the face, px/s^2
const LIFT := 1500.0              # enemy acceleration toward the face
const LIFT_MAX := 230.0
const ITEM_MAX := 240.0           # iron flying in still stings what's in the way

var on := false
var lifted := 0                   # enemies it has hauled up (tests)
var _t := 0.0
var _spr: Sprite2D
var _light: PointLight2D
var _rate := Power.UNPOWERED
var _rate_t := 0.0
var _holding := {}


func _ready() -> void:
	z_index = 2
	_spr = Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = preload("res://assets/sprites/magnet.png")
	a.region = Rect2(0, 0, 36, 40)
	_spr.texture = a
	_spr.centered = false
	_spr.offset = Vector2(-18, -2)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	_light = PointLight2D.new()
	_light.texture = LightTextures.create_radial_light(96)
	_light.color = Color(0.5, 0.8, 1.0)
	_light.energy = 0.0
	_light.position = FACE
	add_child(_light)
	_t = OFF_TIME * 0.5


func reach() -> float:
	return (REACH + 45.0 * clampf((_rate - Power.UNPOWERED) / (1.0 - Power.UNPOWERED), 0.0, 1.0)) * Tech.mult("magnets")


func _physics_process(delta: float) -> void:
	if _light == null:
		return
	_rate_t -= delta
	if _rate_t <= 0:
		_rate_t = 0.25
		_rate = Power.rate_at(get_tree(), global_position)
	_t -= delta
	if _t <= 0:
		_switch(not on)
	if not on:
		return
	var face := to_global(FACE)
	var r := reach()
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or not o.get("kind") in METAL or o.has_meta("store_material"):
			continue
		var d: Vector2 = face - o.global_position
		var dist := d.length()
		if dist > r:
			continue
		o.sleeping = false
		if dist < 9.0:
			o.linear_velocity *= 0.7          # stuck to the face
			o.linear_velocity.y -= 980.0 * delta
		else:
			var k := 1.0 - dist / r
			o.linear_velocity += d / dist * (PULL * (0.35 + 0.65 * k)) * delta + Vector2(0, -980.0 * delta * k)
			o.linear_velocity = o.linear_velocity.limit_length(ITEM_MAX)   # a clatter, not a gun
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying) or _too_heavy(e):
			continue
		var at: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var d: Vector2 = face + Vector2(0, 12) - at
		var dist := d.length()
		if dist > r:
			continue
		if e is CharacterBody2D and "_knock_t" in e:
			if not _holding.has(e):
				_holding[e] = true
				lifted += 1
				FX.burst(get_parent(), at, Color(0.6, 0.85, 1.0), 5, 60.0, 0.3, 1.2)
			e._knock_t = 0.12          # its legs have nothing to push against
			var v: Vector2 = e.velocity + d / maxf(dist, 1.0) * LIFT * Tech.mult("magnets") * delta + Vector2(0, -980.0 * delta)
			if dist < 10.0:
				v *= 0.5
			e.velocity = v.limit_length(LIFT_MAX)
		elif "velocity" in e:   # magpies get dragged off course
			e.velocity += d / maxf(dist, 1.0) * LIFT * 0.4 * delta


func _too_heavy(e) -> bool:
	if e.get("enemy_type") == 0:          # titan
		return true
	return e.get_script() != null and e.get_script().resource_path.get_file() in ["bridger.gd", "sapper.gd", "foundry.gd", "airship.gd"]


func _switch(to_on: bool) -> void:
	on = to_on
	_t = ON_TIME if on else OFF_TIME
	(_spr.texture as AtlasTexture).region = Rect2(36 if on else 0, 0, 36, 40)
	_light.energy = 0.9 if on else 0.0
	if on:
		SFX.play_small(self, SFX.sfx_laser(), -12.0, 0.5)
	else:
		# the field collapses with a snap: what it held is flung down
		for e in _holding:
			if is_instance_valid(e) and not ("_dying" in e and e._dying):
				e.velocity = Vector2(e.velocity.x * 0.3, 160.0)
				e._knock_t = 0.2
		_holding.clear()
		SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.5)
		FX.burst(get_parent(), to_global(FACE), Color(0.6, 0.85, 1.0, 0.7), 6, 40.0, 0.3, 1.2)
