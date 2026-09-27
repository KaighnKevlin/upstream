extends Node2D
## Readout for a flip-flop counter: a glowing 0 or 1 beside each bit (with
## its place value) and the count they add up to, in brass numerals.
## `bits` are rockers, least significant first; tipped right = 1.

var bits: Array = []
var counted := 0                 # tests: the value last drawn


func value() -> int:
	var v := 0
	for k in bits.size():
		if is_instance_valid(bits[k]) and bits[k].tilt > 0:
			v += 1 << k
	return v


func _process(_delta: float) -> void:
	var v := value()
	if v != counted:
		counted = v
		queue_redraw()


func _draw() -> void:
	if bits.is_empty():
		return
	var font := ThemeDB.fallback_font
	var s := ""
	for k in bits.size():
		var b = bits[k]
		if not is_instance_valid(b):
			continue
		var on: bool = b.tilt > 0
		s = ("1" if on else "0") + s
		var p: Vector2 = b.global_position + Vector2(24, -8)
		draw_string(font, p, "1" if on else "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1.0, 0.82, 0.4) if on else Color(0.45, 0.4, 0.35))
		draw_string(font, p + Vector2(0, 11), str(1 << k), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.52, 0.4))
	var top: Vector2 = bits[0].global_position + Vector2(200, 90)
	draw_rect(Rect2(top - Vector2(8, 26), Vector2(170, 56)), Color(0.08, 0.06, 0.05, 0.85))
	draw_rect(Rect2(top - Vector2(8, 26), Vector2(170, 56)), Color(0.72, 0.55, 0.3), false, 2.0)
	draw_string(font, top, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.82, 0.4))
	draw_string(font, top + Vector2(0, 22), "= %d" % counted, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 0.88, 0.92))
