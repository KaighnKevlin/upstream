extends Node2D
## Dotted ballistic arc for aiming launchers: from `origin` with `velocity`
## under gravity, stopping at the first solid tile. Drawn in world space.

var origin := Vector2.ZERO
var velocity := Vector2.ZERO
var gravity := 980.0
var tilemap: TileMapLayer
const STEP := 0.035
const MAX_T := 2.2


func _ready() -> void:
	top_level = true
	z_index = 20


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var t := 0.0
	var k := 0
	while t < MAX_T:
		var p := origin + velocity * t + Vector2(0, 0.5 * gravity * t * t)
		if tilemap and tilemap.get_cell_source_id(tilemap.local_to_map(tilemap.to_local(p))) != -1:
			draw_circle(p, 3.5, Color(0.08, 0.06, 0.1, 0.8))
			draw_circle(p, 2.5, Color(1.0, 0.55, 0.3, 1.0))  # where it lands
			return
		if k % 2 == 0:  # every other step: evenly spaced beads
			var fade := 1.0 - 0.5 * t / MAX_T  # stays readable to the end
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.08, 0.06, 0.1, 0.8 * fade))  # dark rim
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.75, 0.97, 1.0, fade))
		t += STEP
		k += 1
