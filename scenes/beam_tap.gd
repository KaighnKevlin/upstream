extends Node2D
## Beam tap: a brass collar fitted around the Beam at some height. Pieces
## rising past it that match its filter are pulled out sideways through
## its spout (toward the side it was placed on), the rest rise on. Click
## it to cycle the filter: copper, iron, scrap, grit, ingots, anything.
## Height matters: a piece taken out low arrives sooner but has less drop
## left to spend on wheels.

const SFX = preload("res://scripts/sfx.gd")
const FX = preload("res://scripts/fx.gd")

const FILTERS := ["copper", "iron", "scrap", "grit", "ingot", "any"]
const COLORS := {"copper": Color(0.95, 0.55, 0.3), "iron": Color(0.6, 0.65, 0.75), "scrap": Color(0.7, 0.6, 0.45),
	"grit": Color(0.8, 0.75, 0.65), "ingot": Color(1.0, 0.85, 0.4), "any": Color(0.6, 0.9, 1.0)}
const BAND := 12.0

@export var mode := 0             # index into FILTERS
@export var side := 1.0           # which way the spout faces

var tapped := 0                   # tests
var _beam: Node2D = null
var _spr: Sprite2D               # the collar, pixel art (mirrored to the spout's side)


func _ready() -> void:
	z_index = 2
	# sprite first (ghosts too), under our _draw (the filter lamp)
	_spr = Sprite2D.new()
	_spr.texture = preload("res://assets/sprites/beam_tap.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.show_behind_parent = true
	add_child(_spr)
	if has_meta("ghost"):
		return
	add_to_group("beam_taps")
	_attach.call_deferred()


func _attach() -> void:
	var best_d := 60.0
	for b in get_tree().get_nodes_in_group("beams"):
		var d := absf(b.global_position.x - global_position.x)
		if d < best_d and global_position.y > b.top_y() and global_position.y < b.bottom_y():
			best_d = d
			_beam = b
	if _beam:
		side = 1.0 if global_position.x >= _beam.global_position.x else -1.0
		global_position.x = _beam.global_position.x
	queue_redraw()


func _matches(o: RigidBody2D) -> bool:
	var f: String = FILTERS[mode]
	if f == "any":
		return true
	if f == "ingot":
		return o.is_in_group("ingots")
	return o.is_in_group("ore") and o.get("kind") == f


func _physics_process(_delta: float) -> void:
	if _beam == null or not is_instance_valid(_beam):
		return
	for b in _beam._area.get_overlapping_bodies():
		if not (b is RigidBody2D) or not b.has_meta("in_beam"):
			continue
		var o := b as RigidBody2D
		if absf(o.global_position.y - global_position.y) > BAND or not _matches(o):
			continue
		_beam.release(o, global_position + Vector2(side * 22.0, 0), Vector2(side * 150.0, -40.0))
		tapped += 1
		SFX.play_small(self, SFX.sfx_clink(), -12.0, 1.8)
		FX.burst(get_parent(), global_position + Vector2(side * 16.0, 0), COLORS[FILTERS[mode]], 3, 40.0, 0.2, 1.0)


func _draw() -> void:
	var col: Color = COLORS[FILTERS[mode]]
	var w := 34.0
	# the collar is _spr (spout toward side); the filter lamp opposite it
	_spr.scale = Vector2(side, 1)
	draw_circle(Vector2(-side * w * 0.5, 0), 2.0, col)


func _input(event: InputEvent) -> void:
	if has_meta("ghost"):
		return
	if has_node("/root/BuildSystem") and get_node("/root/BuildSystem").current_build != 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Pointer.world(self).distance_to(global_position) < 18:
			mode = (mode + 1) % FILTERS.size()
			SFX.play(self, SFX.sfx_clink())
			queue_redraw()
			var scene := get_tree().current_scene
			if scene.has_method("_show_banner"):
				scene._show_banner("BEAM TAP", "takes out: %s" % FILTERS[mode])
			get_viewport().set_input_as_handled()
