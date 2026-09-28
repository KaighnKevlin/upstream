extends Node2D
## Steam jet: a little brass boiler on legs with a ring of nozzles, set down
## beside a powered machine. It spends the power belted to it (a gravity
## wheel in reach) raising steam; with a full head it waits, and the moment
## a rust mite is clinging to anything within REACH it lets the lot go in
## one scalding blast: mites near it are scalded to death, ones further out
## are blown off their piece to crawl back. Then it builds steam again
## (CHARGE seconds with full power; unpowered, about three times as long,
## and mites on it slow it like any machine). A piece of ore dropped in its
## firebox (coal, in effect) gives it a full head at once, so it works off
## the belt too. Mites crawling about near it get blown away with the rest.
## Triggerable: a tripwire or listener lets a full head go at once.

const Power = preload("res://scripts/power.gd")
const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const REACH := 84.0               # mites within this of the nozzles are hit
const KILL := 50.0                # ... and this close, killed outright
const CHARGE := 3.0               # s to a full head of steam, fully powered
const BLOW := 220.0               # how hard the ones further out are blown off
const NOZZLE := Vector2(0, -24)
const FIREBOX := Vector2(0, -8)

var pressure := 0.0               # 0..1
var blasts := 0                   # tests
var killed := 0
var knocked := 0
var burned := 0                   # ore fed to the firebox
var rate := Power.UNPOWERED
var _rate_t := 0.0
var _puff := 0.0                  # the blast ring, 1 -> 0
var _anim := 0.0


func _ready() -> void:
	z_index = 2
	# the boiler's sprite first, so ghosts and build-bar icons get it too;
	# behind our own _draw (the firebox glow, the needle, the steam)
	var art := Sprite2D.new()
	art.texture = preload("res://assets/sprites/steam_jet.png")
	art.centered = false
	art.offset = Vector2(-11, -31)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.show_behind_parent = true
	add_child(art)
	if has_meta("ghost"):
		return
	add_to_group("power_users")
	add_to_group("steam_jets")
	add_to_group("triggerable")


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_anim += delta
	_puff = maxf(0.0, _puff - delta * 2.5)
	_rate_t -= delta
	if _rate_t <= 0.0:
		_rate_t = 0.25
		rate = Power.rate_at(get_tree(), global_position)
	pressure = minf(1.0, pressure + rate / CHARGE * delta)
	if pressure < 1.0:
		_stoke()
	elif _mite_in_reach():
		blast()
	queue_redraw()


## Ore rolling into the firebox door is burned: a full head of steam.
func _stoke() -> void:
	var at := global_position + FIREBOX
	for o in get_tree().get_nodes_in_group("ore"):
		if not is_instance_valid(o) or o.freeze or o.is_queued_for_deletion():
			continue
		if o.global_position.distance_to(at) < 10.0 and o.get("kind") != null:
			o.queue_free()
			burned += 1
			pressure = 1.0
			FX.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 6, 60.0, 0.3, 1.4, -40.0)
			SFX.play_small(self, SFX.sfx_ore_knock("metal"), -14.0, 0.7)
			return


func _mite_in_reach() -> bool:
	var at := global_position + NOZZLE
	for m in get_tree().get_nodes_in_group("rust_mites"):
		if is_instance_valid(m) and m.clinging_to != null and m.global_position.distance_to(at) < REACH:
			return true
	return false


## Lets the whole head of steam go (a trigger fires it too, if it's full).
func blast() -> void:
	if pressure < 1.0:
		return
	pressure = 0.0
	blasts += 1
	_puff = 1.0
	var at := global_position + NOZZLE
	for m in get_tree().get_nodes_in_group("rust_mites").duplicate():
		if not is_instance_valid(m) or m.get("_dying"):
			continue
		var d: Vector2 = m.global_position - at
		if d.length() >= REACH:
			continue
		FX.burst(get_parent(), m.global_position, Color(0.95, 0.95, 0.95, 0.8), 3, 40.0, 0.4, 1.8, -30.0)
		if d.length() < KILL:
			killed += 1
			m.take_damage(1)
		else:
			knocked += 1
			m.knock(d.normalized() * BLOW + Vector2(0, -80))
	for i in 10:
		var a := TAU * i / 10.0
		FX.burst(get_parent(), at + Vector2(cos(a), sin(a)) * 8.0, Color(0.92, 0.93, 0.95, 0.75), 2, 160.0, 0.5, 2.6, -20.0)
	SFX.play_small(self, SFX.sfx_shotgun(), -10.0, 0.5)


func trigger() -> void:
	blast()


func _draw() -> void:
	var dark := Color(0.1, 0.08, 0.07)
	# the legs, drum, bands, door frame, gauge face and nozzle rose are art
	# firebox door, glowing with the steam it's raising
	var glow := Color(1.0, 0.5, 0.15).lerp(Color(0.3, 0.12, 0.05), 1.0 - clampf(rate, 0.0, 1.0))
	draw_rect(Rect2(-2, -11, 4, 2), glow)
	# the gauge's needle: up with the pressure
	var g := Vector2(8, -15)
	var a := PI * 0.75 + pressure * PI * 1.5
	draw_line(g, g + Vector2(cos(a), sin(a)) * 2.6, Color(0.8, 0.2, 0.15) if pressure >= 1.0 else dark, 1.0)
	# full: a wisp of steam leaking from the safety valve
	if pressure >= 1.0:
		var w := sin(_anim * 6.0)
		draw_circle(NOZZLE + Vector2(w * 1.5, -6 - fmod(_anim * 10.0, 6.0)), 1.6, Color(0.95, 0.95, 0.95, 0.5))
	# the blast: a ring of steam out to REACH
	if _puff > 0.0:
		var r := REACH * (1.0 - _puff * _puff)
		draw_arc(NOZZLE, r, 0, TAU, 32, Color(0.95, 0.95, 0.97, 0.55 * _puff), 5.0 * _puff + 1.0)
		draw_circle(NOZZLE, r * 0.5, Color(0.95, 0.95, 0.97, 0.18 * _puff))
