extends Node2D
## Panning box: a short slatted riffle box set on a flume's floor. Grit the
## current carries through it is caught behind the riffles (up to CAP) and
## washed there: every three washed leave one small copper nugget, let go
## over the tail board to float on downstream; the tailings wash away.
## Everything else floats or creeps over it untouched. Out of the water it
## does nothing (and shows dry). Faces the way the flume runs.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")
const ORE := preload("res://scenes/ore.tscn")

const HALF := 20.0               # half its length
const CATCH_H := 18.0            # how high over the bed it takes grit from
const PER_NUGGET := 3
const CAP := 9
const WASH := 0.5                # s to wash one grit
const RIFFLES := [-11.0, -3.0, 5.0, 13.0]

var held := 0                    # grit behind the riffles (tests)
var caught := 0                  # grit taken in, all told (tests)
var washed := 0                  # grit washed (tests)
var nuggets := 0                 # nuggets let go (tests)
var _flow := 0.0                 # -1/0/+1: the water it sits in
var _side := 1.0                 # the way it faces (the last current it felt)
var _check := 0.0
var _wash := 0.0
var _toward := 0                 # grit washed toward the next nugget
var _t := 0.0
var _flash := 0.0
var _art: Node2D                 # the box and riffles, drawn for a rightward run


func _ready() -> void:
	z_index = 2
	# the sprites first, so ghosts and build-bar icons get them too; behind
	# our own _draw (the grit in the pockets, the water over it, the count)
	_art = Node2D.new()
	_art.show_behind_parent = true
	add_child(_art)
	_art.add_child(_spr(preload("res://assets/sprites/panning_box.png"), Vector2(-22, -11)))
	_art.add_child(_spr(preload("res://assets/sprites/panning_riffles.png"), Vector2(-22, -11)))
	if has_meta("ghost"):
		return
	add_to_group("panning_boxes")


func _spr(tex: Texture2D, off: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = off
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sp


func _physics_process(delta: float) -> void:
	if has_meta("ghost"):
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_flow = 0.0
		var bed := global_position + Vector2(0, -4)
		for f in get_tree().get_nodes_in_group("flumes"):
			if is_instance_valid(f):
				var w: float = f.water_at(bed)
				if w != 0.0:
					_flow = w
					_side = w
					break
	if _flow != 0.0:
		# grit riding the current through the box drops behind a riffle
		for o in get_tree().get_nodes_in_group("ore"):
			if held >= CAP:
				break
			if not is_instance_valid(o) or o.is_queued_for_deletion() or o.freeze or o.get("kind") != "grit" \
					or o.has_meta("caught_by") or o.has_meta("store_material"):
				continue
			var p := to_local(o.global_position)
			if absf(p.x) < HALF and p.y < 2.0 and p.y > -CATCH_H:
				held += 1
				caught += 1
				o.queue_free()
				SFX.play_small(self, SFX.sfx_ore_knock("ore"), -24.0, 1.7)
		# and washes, one at a time
		if held > 0:
			_wash += delta
			if _wash >= WASH:
				_wash = 0.0
				held -= 1
				washed += 1
				_toward += 1
				if _toward >= PER_NUGGET:
					_toward = 0
					_nugget()
		else:
			_wash = 0.0
	queue_redraw()


func _nugget() -> void:
	nuggets += 1
	_flash = 1.0
	# let go just past the tail board, up in the current, so it floats on
	var at := global_position + Vector2(_side * (HALF + 6.0), -10.0)
	var o: RigidBody2D = ORE.instantiate()
	o.kind = "copper"
	o.set_meta("nugget", true)
	o.global_position = at
	get_tree().current_scene.add_child(o)
	o.linear_velocity = Vector2(_side * 60.0, -20.0)
	FX.burst(get_parent(), at, Color(1.0, 0.75, 0.4, 0.8), 4, 25.0, 0.3, 1.2)
	SFX.play_small(self, SFX.sfx_clink(), -14.0, 1.6)


func _draw() -> void:
	# the box and riffles are sprites (see _ready), mirrored to the current
	if _art.scale.x != _side:
		_art.scale = Vector2(_side, 1)
	var wet := _flow != 0.0
	_art.modulate = Color(1, 1, 1) if wet else Color(1.18, 1.12, 1.02)
	# the grit caught in the pockets, upstream of each riffle, glinting
	for i in held:
		var r: float = RIFFLES[i % RIFFLES.size()] * _side
		var k := floori(float(i) / RIFFLES.size())
		var p := Vector2(r - _side * (2.0 + k * 1.6), -2.5 - (k % 2))
		if wet:
			p.x += sin(_t * 9.0 + i * 1.7) * 0.4
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color(0.74, 0.68, 0.6))
		if wet and fposmod(_t * 2.3 + i * 0.37, 1.0) < 0.3:
			draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(1, 1)), Color(1.0, 0.88, 0.55))
	if _flash > 0.0:
		draw_circle(Vector2(_side * (HALF - 2), -4), 2.0 + _flash * 2.0, Color(1.0, 0.75, 0.4, _flash * 0.6))
	if has_meta("ghost"):
		return
	if wet:
		# under the flume's water (it draws below us): a wash of it over the box
		draw_rect(Rect2(-HALF - 2, -11, HALF * 2 + 4, 11), Color(0.3, 0.55, 0.85, 0.14))
		# water swirling in the pockets: little eddies curling back behind the slats
		for j in RIFFLES.size():
			var x: float = RIFFLES[j] * _side
			var a := _t * 6.0 + j * 1.3
			var c := Vector2(x - _side * 3.0, -5.0)
			var e := c + Vector2(cos(a) * 2.2, sin(a) * 1.4)
			draw_line(c + Vector2(cos(a - 1.2) * 2.2, sin(a - 1.2) * 1.4), e, Color(0.8, 0.92, 1.0, 0.5), 1.0)
		# the cloudy tailings washing out over the tail board while it works
		if held > 0:
			for j in 3:
				var f := fposmod(_t * 1.6 + j / 3.0, 1.0)
				draw_circle(Vector2(_side * (HALF + f * 14.0), -3.0 - f * 3.0), 1.2 + f * 1.5, Color(0.6, 0.55, 0.48, 0.35 * (1.0 - f)))
	# what it holds and what it's let go: grit / nuggets over the head board
	var font := ThemeDB.fallback_font
	var col := Color(1.0, 0.9, 0.62) if wet else Color(0.62, 0.58, 0.54)
	draw_string(font, Vector2(-12, -14), "%d / %d" % [held, nuggets], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	for i in PER_NUGGET:
		var p := Vector2(10 + i * 4, -17)
		draw_circle(p, 1.5, Color(0.1, 0.08, 0.07))
		if i < _toward:
			draw_circle(p, 1.0, Color(0.95, 0.6, 0.3))
