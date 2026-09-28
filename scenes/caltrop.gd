extends Node2D
## Caltrop: a four-spiked iron star a caltrop spreader flings low across
## the floor. It lands where it was aimed (on the tile surface there) and
## lies in wait; the first walker whose feet come down on it takes a spike:
## a little damage and a limp (slowed for a moment). Then it's spent.
## Not a body: pieces and the player pass over it.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const DAMAGE := 1
const LIMP := 0.4                # a limping walker's speed, x its own
const LIMP_TIME := 1.5
const REACH := 7.0               # feet this close (x) step on it

var landed := false
var spent := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _arc := 0.0
var _dur := 0.4
var _t := 0.0
var _spin := 0.0
var _victim: WeakRef             # the walker it lamed, until its limp wears off
var _art: Sprite2D


func _ready() -> void:
	z_index = 1
	_art = Sprite2D.new()
	_art.texture = preload("res://assets/sprites/caltrop.png")
	_art.hframes = 3
	_art.frame = randi() % 3
	_art.centered = false
	_art.offset = Vector2(-4, -6)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_art)


## Throw it from `from` (global) to land at `to`, `arc` px high at the top.
func fling(from: Vector2, to: Vector2, arc: float) -> void:
	_from = from
	_to = to
	_arc = arc
	_dur = 0.22 + from.distance_to(to) / 420.0
	_spin = randf_range(14.0, 22.0) * signf(to.x - from.x)
	global_position = from


func _physics_process(delta: float) -> void:
	if spent:
		return
	if not landed:
		_t = minf(1.0, _t + delta / _dur)
		global_position = _from.lerp(_to, _t) + Vector2(0, -_arc * 4.0 * _t * (1.0 - _t))
		rotation += _spin * delta
		if _t >= 1.0:
			landed = true
			rotation = 0.0
			SFX.play_small(self, SFX.sfx_clink(), -20.0, randf_range(2.2, 2.8))
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or ("_dying" in e and e._dying):
			continue
		# a walker's origin rides ~13 px above its feet
		var p: Vector2 = e.global_position - global_position
		if absf(p.x) < REACH and p.y > -26 and p.y < 4:
			_step(e)
			return


## A walker's foot comes down on it.
func _step(e: Node) -> void:
	spent = true
	visible = false
	remove_from_group("caltrops")
	FX.burst(get_parent(), global_position + Vector2(0, -2), Color(0.75, 0.8, 0.8), 4, 60.0, 0.2, 1.5, -30.0)
	SFX.play_small(self, SFX.sfx_clink(), -10.0, 1.6)
	if "speed" in e:
		# stacked limps share one slow-down; the last to wear off lifts it
		var n: int = e.get_meta("caltrop_limp", 0)
		if n == 0:
			e.speed *= LIMP
		e.set_meta("caltrop_limp", n + 1)
		_victim = weakref(e)
	if e.has_method("take_damage"):
		e.take_damage(DAMAGE)
	if _victim == null:
		queue_free()
		return
	# stay (hidden) as the limp's timer
	await get_tree().create_timer(LIMP_TIME, false).timeout
	var v = _victim.get_ref()
	if v and is_instance_valid(v):
		var n: int = v.get_meta("caltrop_limp", 1) - 1
		v.set_meta("caltrop_limp", n)
		if n <= 0:
			v.speed /= LIMP
	queue_free()


## Cleared away (the spreader's too many out): gone without a trace, unless
## it's still timing a limp.
func vanish() -> void:
	if not spent:
		queue_free()
