extends Node2D
## Pop-up barricade: a riveted iron slab hidden in a slot flush with the
## ground. When a linked trigger fires (a tripwire, a pressure plate, a
## clockwork timer) it springs up three tiles high in a blink, a wall the
## pack has to stop at or climb, and holds for HOLD seconds before sinking
## back into its slot. Anything standing on the slot when it fires is
## thrown up. Bunch the pack up in front of your turrets and traps with it.
## Art: tools/art/gen_barricade.py (slab 18x50, slot 26x6).

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const HEIGHT := 48.0
const HOLD := 4.0
const RISE := 0.12
const SINK := 0.6

var raised := 0                  # tests
var _h := 0.0
var _hold := 0.0
var _busy := false
var _slab: Sprite2D
var _shape: RectangleShape2D
var _cs: CollisionShape2D


func _ready() -> void:
	z_index = 1
	if not has_meta("ghost"):
		_snap_to_floor()
	var slot := Sprite2D.new()
	slot.texture = preload("res://assets/sprites/barricade_slot.png")
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.position = Vector2(0, -1)
	slot.z_index = 1
	add_child(slot)
	_slab = Sprite2D.new()
	_slab.texture = preload("res://assets/sprites/barricade.png")
	_slab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slab.centered = false
	_slab.region_enabled = true
	add_child(_slab)
	if has_meta("ghost"):
		_set_height(HEIGHT * 0.5)
		return
	add_to_group("triggerable")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_cs = CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(16, 1)
	_cs.shape = _shape
	_cs.disabled = true
	body.add_child(_cs)
	add_child(body)
	_set_height(0.0)


func _snap_to_floor() -> void:
	var tm := get_tree().current_scene.get_node_or_null("TileMapLayer") as TileMapLayer
	if tm == null:
		return
	var cell := tm.local_to_map(tm.to_local(global_position))
	for i in 8:
		if tm.get_cell_source_id(cell + Vector2i(0, 1)) != -1:
			break
		cell.y += 1
	global_position = Vector2(global_position.x, tm.to_global(tm.map_to_local(cell)).y + 8)


## Only the part above the ground shows (and collides).
func _set_height(h: float) -> void:
	_h = h
	_slab.visible = h > 0.5
	_slab.region_rect = Rect2(0, 0, 18, maxf(1.0, h))
	_slab.offset = Vector2(-9, -h)
	if _shape:
		_shape.size = Vector2(16, maxf(1.0, h))
		_cs.position = Vector2(0, -h * 0.5)
		_cs.set_deferred("disabled", h < 2.0)


## A tripwire, a plate, a timer: up it comes.
func trigger() -> void:
	if _busy:
		_hold = HOLD          # already up: keep it up
		return
	_busy = true
	raised += 1
	_hold = HOLD
	# whatever is standing on the slot gets flung
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("knock") and absf(e.global_position.x - global_position.x) < 12 \
				and absf(e.global_position.y - global_position.y) < 20:
			e.knock(Vector2(0, -420))
	var p := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if p and absf(p.global_position.x - global_position.x) < 12 and absf(p.global_position.y - global_position.y) < 20 and p.has_method("launch"):
		p.launch(Vector2(0, -460))
	var t := create_tween()
	t.tween_method(_set_height, _h, HEIGHT, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SFX.play(self, SFX.sfx_ore_knock("metal"), 0.0, 0.6)
	FX.burst(get_parent(), global_position, Color(0.6, 0.5, 0.4), 10, 90.0, 0.4, 1.8)
	FX.shake(self, 2.0, 0.12)


func _process(delta: float) -> void:
	if not _busy or has_meta("ghost"):
		return
	if _h >= HEIGHT - 0.5:
		_hold -= delta
		if _hold <= 0:
			_busy = false
			var t := create_tween()
			t.tween_method(_set_height, _h, 0.0, SINK).set_trans(Tween.TRANS_SINE)
			SFX.play_small(self, SFX.sfx_clink(), -8.0, 0.6)
