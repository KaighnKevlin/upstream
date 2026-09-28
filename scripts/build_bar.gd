extends Control
## Build toolbar: pieces grouped into tabs (Transport, Production, Defence,
## Traps, Marble, Lifts, Logic),
## one slot per piece drawn from its own sprites, with its hotkey. Click a
## tab to switch; click a slot (or press its key, from any tab) to build it;
## click the selected slot again to cancel. Pressing a piece's key flips to
## its tab. Hovering a slot names it beside the tabs.

const TAB_H := 16.0
const TAB_W := 100.0           # seven tabs across the panel
const SLOT := Vector2(48, 44)          # 13 to a tab fit the panel
const GAP := 5.0
const ICON_BOX := Vector2(43, 36)

const DARK := Color(0.1, 0.09, 0.07)
const WELL := Color(0.16, 0.13, 0.1)
const RIM := Color(0.45, 0.37, 0.26)
const RIM_ON := Color(1.0, 0.78, 0.35)
const KEY_COL := Color(0.9, 0.82, 0.62)
const TAB_BG := Color(0.3, 0.24, 0.17)
const TAB_ON := Color(0.52, 0.41, 0.27)

# build type -> [hotkey label, name]
const PIECES := {
	1: ["1", "Trampoline"], 2: ["2", "Vein tapper"], 3: ["3", "Laser smelter"],
	4: ["4", "Upstream lift"], 5: ["5", "Drop hopper"], 6: ["6", "Funnel turret"],
	7: ["7", "Spikes"], 8: ["8", "Catapult"], 9: ["9", "Chute"], 10: ["0", "Splitter"],
	11: ["B", "Bumper"], 12: ["C", "Conveyor belt"], 13: ["V", "Bellows fan"],
	14: ["M", "Wrecking pendulum"], 15: ["N", "Gravity wheel"], 16: ["T", "Assembler"],
	17: ["Y", "Research lab"], 18: ["U", "Tesla coil"], 19: ["I", "Flame turret"], 20: ["X", "Trapdoor"], 21: ["R", "Crusher"], 22: ["Z", "Electromagnet"], 23: ["", "Harpoon ballista (anti-air)"], 24: ["", "Seesaw"], 25: ["", "Pneumatic tube"], 26: ["", "Powder keg"], 27: ["", "Snare (bear trap)"], 28: ["", "Tripwire (drag stake to stake)"], 29: ["", "Pressure plate"], 30: ["", "Steam borer (click: turn)"], 31: ["", "Lantern"], 32: ["", "Brass sentry (feed it an ingot to rewind)"], 33: ["", "Clockwork timer (click: 2/4/8 s)"], 34: ["", "Drone dock (porters tidy loose ore)"], 35: ["", "Pop-up barricade (wire it to a trigger)"], 36: ["", "Steam engine (burns ore: powers machines)"], 37: ["", "Domino row (drag; click an end to reset)"], 38: ["", "Beam tap (click: filter)"], 39: ["", "Flip-flop (every other)"], 40: ["", "Escapement (one per beat)"], 41: ["", "Tipping bucket (batches)"], 42: ["", "Sieve rail (drag; grit drops)"], 43: ["", "Archimedes screw (drag up)"], 44: ["", "Robotic arm (click: filter)"], 45: ["", "Stair lift (climbs marbles up)"], 46: ["", "Ferris lift (cups carry marbles up)"], 47: ["", "Jump (drag: landing; slow ones drop short)"], 48: ["", "Bell (a marble rings it: fires linked traps)"], 49: ["", "Loop-the-loop (needs a fast marble)"], 50: ["", "Dispenser (a marble every 1/2/4 s: click)"], 51: ["", "Goal cup (counts marbles; fires traps when full)"], 52: ["", "Weigh scale (heavy one way, light the other: click)"], 53: ["", "Marble cannon (fires marbles flat: iron through shields)"], 54: ["", "Felt chute (drag: quiet, a little slow)"], 55: ["", "Chime bar (drag; click: note)"], 56: ["", "Plunger (click-hold, release: fires a marble up)"], 57: ["", "Vortex funnel (spirals marbles, one at a time)"], 58: ["", "Flap sorter (drag; heavy drops through, click a flap: spring)"], 59: ["", "Overflow gate (drag its ring to what it feeds)"], 60: ["", "Deflector plate (ricochets flying ore: click to turn)"], 61: ["", "Booster rail (drag the way it drives: climbs; powered)"], 62: ["", "Catch net (catches flying ore, drops it at one point)"], 63: ["", "Magnet drum (at a chute end: iron drops behind, copper flies on)"], 64: ["", "Sluice gate (holds ore back; a trigger or click opens it)"], 65: ["", "Tally wheel (every 3/5/10 pieces fires its wire: click)"], 66: ["", "Points switch (stays put; a trigger or click throws it)"], 67: ["", "Brake rail (drag; caps speed: click its number)"], 68: ["", "Teeter launcher (a drop flings the one waiting)"], 69: ["", "Crossover (two streams cross, each keeps its line)"], 70: ["", "Flywheel (stores a wheel's surplus power)"], 71: ["", "Rotary distributor (three ways, in turn)"], 72: ["", "Flipper (a trigger or click bats what's on it)"], 73: ["", "Counterweight lift (heavy down lifts light up)"], 74: ["", "Pair gate (AND: one from each side, together)"], 75: ["", "Furnace rail (drag; slow ore comes off as ingots)"], 76: ["", "Silo (stores 40; lets them out on a clock or trigger)"], 77: ["", "Ropeway (drag high post to low: zips ore across)"], 78: ["", "Load cell (fires its wire when the pan is full)"], 79: ["", "Banked turn (U-turn corner that keeps the speed)"], 80: ["", "Gauss cannon (a roll in shoots the waiting one out fast)"], 81: ["", "Treadwheel (walk in it: power by hand)"], 82: ["", "Trebuchet (weight in the box throws the sling far)"],
}
const CATS := [
	["Transport", [1, 60, 62, 9, 67, 12, 25, 10, 8, 24, 4, 13, 31]],
	["Production", [2, 30, 3, 75, 15, 81, 70, 36, 16, 21, 17, 34]],
	["Defence", [32, 6, 53, 82, 18, 23, 19, 5, 22, 26]],
	["Traps", [7, 27, 20, 11, 14, 28, 29, 33, 35, 37]],
	["Marble", [38, 79, 52, 58, 63, 41, 42, 54, 69, 47, 49, 68, 80]],
	["Lifts", [61, 73, 77, 43, 44, 45, 46, 56, 57, 55, 50, 76, 51]],
	# what reacts to signals and routes by them
	["Logic", [39, 71, 66, 74, 59, 40, 65, 78, 64, 72, 48]],
]

var font: Font
var _cat := 0
var _current := 0
var _hover := -1
var _name_label: Label
var _icons := {}             # build type -> icon holder


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var most := 0
	for c in CATS:
		most = maxi(most, c[1].size())
	size = Vector2(maxf(most * (SLOT.x + GAP) - GAP, CATS.size() * TAB_W), TAB_H + 2 + SLOT.y)
	for t in PIECES:
		var holder := Node2D.new()
		add_child(holder)
		_build_icon(holder, t)
		_icons[t] = holder
	_name_label = Label.new()
	_name_label.visible = false
	_name_label.z_index = 5
	if font:
		_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", KEY_COL)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.position = Vector2(4, -20)   # above the tabs (six tabs leave no room beside them)
	add_child(_name_label)
	_layout()
	var bs := get_node("/root/BuildSystem")
	bs.build_mode_changed.connect(_on_build_mode)
	bs.ui_rects.append(get_global_rect)


func _types() -> Array:
	return CATS[_cat][1]


func _layout() -> void:
	for t in _icons:
		_icons[t].visible = false
	var types := _types()
	for i in types.size():
		var h: Node2D = _icons[types[i]]
		h.visible = true
		h.position = _slot_rect(i).get_center() + Vector2(0, 2)
	queue_redraw()


func _on_build_mode(t: int) -> void:
	_current = t
	if t != 0 and not t in _types():
		for c in CATS.size():
			if t in CATS[c][1]:
				_cat = c
				_layout()
	queue_redraw()


func _tab_rect(c: int) -> Rect2:
	return Rect2(Vector2(c * TAB_W, 0), Vector2(TAB_W - 4, TAB_H))


func _slot_rect(i: int) -> Rect2:
	return Rect2(Vector2(i * (SLOT.x + GAP), TAB_H + 2), SLOT)


func _slot_at(p: Vector2) -> int:
	for i in _types().size():
		if _slot_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _slot_at(event.position)
		if h != _hover:
			_hover = h
			_name_label.visible = h >= 0
			if h >= 0:
				_name_label.text = PIECES[_types()[h]][1]
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for c in CATS.size():
			if _tab_rect(c).has_point(event.position):
				_cat = c
				_hover = -1
				_layout()
				accept_event()
				return
		var i := _slot_at(event.position)
		if i >= 0:
			var t: int = _types()[i]
			get_node("/root/BuildSystem")._set_build(0 if t == _current else t)
		accept_event()


## Tab flips to the next tab; the mouse wheel steps through the current
## tab's pieces (so every piece has a keyboard/mouse route, hotkey or not).
func _unhandled_input(event: InputEvent) -> void:
	var bs := get_node_or_null("/root/BuildSystem")
	if bs == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_cat = (_cat + 1) % CATS.size()
		_hover = -1
		_layout()
		if _current != 0:
			bs._set_build(_types()[0])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var types := _types()
		var i := types.find(_current)
		var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		i = 0 if i < 0 else posmod(i + step, types.size())
		bs._set_build(types[i])
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		_name_label.visible = false
		queue_redraw()


func _draw() -> void:
	# folder tabs along the top
	for c in CATS.size():
		var r := _tab_rect(c)
		var on := c == _cat
		draw_rect(r, RIM_ON if on else RIM)
		draw_rect(r.grow(-1), TAB_ON if on else TAB_BG)
		if font:
			var label: String = CATS[c][0]
			draw_string(font, r.position + Vector2(7, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
			draw_string(font, r.position + Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, KEY_COL if on else KEY_COL.darkened(0.3))
	var types := _types()
	for i in types.size():
		var r := _slot_rect(i)
		var on: bool = types[i] == _current
		draw_rect(r, RIM_ON if on else RIM)
		draw_rect(r.grow(-2), DARK)
		draw_rect(r.grow(-3), WELL.lightened(0.12) if i == _hover and not on else WELL)
		if font:
			var k: String = PIECES[types[i]][0]
			draw_string(font, r.position + Vector2(5, 15), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.8))
			draw_string(font, r.position + Vector2(4, 14), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RIM_ON if on else KEY_COL)


# ── icons: each piece's own sprites, fitted into the slot ───────────────

func _part(holder: Node2D, path: String, region: Rect2, at: Vector2, flip := false) -> void:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	if region.size != Vector2.ZERO:
		s.region_enabled = true
		s.region_rect = region
	s.position = at
	s.flip_h = flip
	holder.add_child(s)


func _build_icon(slot: Node2D, t: int) -> void:
	var art := Node2D.new()
	slot.add_child(art)
	var S := "res://assets/sprites/"
	match t:
		1:
			_part(art, S + "trampoline_top.png", Rect2(0, 0, 48, 28), Vector2(-24, -12))
			_part(art, S + "trampoline_base.png", Rect2(), Vector2(-14, 12))
		2:
			_part(art, S + "tapper.png", Rect2(0, 0, 40, 46), Vector2(-20, -30))
		3:
			_part(art, S + "electrode.png", Rect2(), Vector2(-26, -10))
			_part(art, S + "electrode.png", Rect2(), Vector2(10, -10), true)
			var arc := Line2D.new()
			arc.points = PackedVector2Array([Vector2(-10, 0), Vector2(-5, -3), Vector2(0, 2), Vector2(5, -2), Vector2(10, 0)])
			arc.width = 2.0
			arc.default_color = Color(0.75, 0.97, 1.0)
			art.add_child(arc)
		4:
			_part(art, S + "upstream-sprite.png", Rect2(), Vector2(-24, -64))
		5:
			_part(art, S + "hopper_back.png", Rect2(), Vector2(-32, -36))
			_part(art, S + "hopper_front.png", Rect2(), Vector2(-32, -36))
		6:
			_part(art, S + "turret_back.png", Rect2(), Vector2(-30, -46))
			_part(art, S + "turret_front.png", Rect2(), Vector2(-30, -46))
			_part(art, S + "turret_barrel.png", Rect2(), Vector2(-5, 28))
		7:
			_part(art, S + "spikes.png", Rect2(), Vector2(-8, -8))
		38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82:
			var scn: String = {38: "beam_tap", 39: "rocker", 40: "escapement", 41: "tipping_bucket", 42: "sieve", 43: "screw", 44: "arm", 45: "stair_lift", 46: "ferris_lift", 47: "jump", 48: "bell", 49: "loop", 50: "dispenser", 51: "goal_cup", 52: "weigh_scale", 53: "cannon", 54: "felt_chute", 55: "chime", 56: "plunger", 57: "vortex", 58: "flap_sorter", 59: "overflow_gate", 60: "deflector", 61: "booster", 62: "catch_net", 63: "magnet_drum", 64: "sluice", 65: "tally", 66: "points", 67: "brake", 68: "teeter", 69: "crossover", 70: "flywheel", 71: "distributor", 72: "flipper", 73: "counterweight", 74: "pair_gate", 75: "furnace_rail", 76: "silo", 77: "ropeway", 78: "load_cell", 79: "banked_turn", 80: "gauss", 81: "treadwheel", 82: "trebuchet"}[t]
			var ic: Node2D = load("res://scenes/%s.gd" % scn).new()
			ic.set_meta("ghost", true)
			ic.scale = Vector2(0.8, 0.8)
			if scn == "sieve":
				ic.end_offset = Vector2(34, 10)
				ic.position = Vector2(-17, -4)
			elif scn == "screw":
				ic.end_offset = Vector2(14, -26)
				ic.position = Vector2(-7, 12)
			elif scn == "arm":
				ic.position = Vector2(0, 14)
			elif scn == "tipping_bucket":
				ic.position = Vector2(8, 6)
			elif scn == "escapement":
				ic.position = Vector2(0, 12)
			elif scn == "rocker" or scn == "weigh_scale" or scn == "overflow_gate" or scn == "points":
				ic.position = Vector2(0, 4)
			elif scn == "stair_lift":
				ic.steps = 4
				ic.position = Vector2(-20, 12)
				ic.scale = Vector2(0.6, 0.6)
			elif scn == "ferris_lift":
				ic.position = Vector2(0, -4)
				ic.scale = Vector2(0.28, 0.28)
			elif scn == "trebuchet":
				ic.position = Vector2(-4, 12)
				ic.scale = Vector2(0.5, 0.5)
			elif scn == "treadwheel":
				ic.scale = Vector2(0.45, 0.45)
			elif scn == "gauss":
				ic.position = Vector2(0, 8)
				ic.scale = Vector2(0.55, 0.55)
			elif scn == "banked_turn":
				ic.position = Vector2(-8, -16)
				ic.scale = Vector2(0.6, 0.6)
			elif scn == "load_cell":
				ic.wire_to = Vector2.ZERO
				ic.position = Vector2(0, 4)
			elif scn == "ropeway":
				ic.end_offset = Vector2(80, 24)
				ic.position = Vector2(-20, 10)
				ic.scale = Vector2(0.5, 0.5)
			elif scn == "silo":
				ic.position = Vector2(0, 14)
				ic.scale = Vector2(0.45, 0.45)
			elif scn == "furnace_rail":
				ic.end_offset = Vector2(34, 8)
				ic.position = Vector2(-17, 0)
			elif scn == "pair_gate":
				ic.position = Vector2(0, 8)
				ic.scale = Vector2(0.75, 0.75)
			elif scn == "counterweight":
				ic.position = Vector2(0, -14)
				ic.scale = Vector2(0.4, 0.4)
			elif scn == "flipper":
				ic.position = Vector2(-14, 6)
				ic.scale = Vector2(0.65, 0.65)
			elif scn == "distributor":
				ic.position = Vector2(0, 6)
			elif scn == "flywheel":
				ic.position = Vector2(0, -4)
				ic.scale = Vector2(0.75, 0.75)
			elif scn == "crossover":
				ic.position = Vector2(0, -2)
				ic.scale = Vector2(0.55, 0.55)
			elif scn == "brake":
				ic.end_offset = Vector2(34, 10)
				ic.position = Vector2(-17, -2)
			elif scn == "tally":
				ic.wire_to = Vector2.ZERO
				ic.scale = Vector2(1.2, 1.2)
			elif scn == "sluice":
				ic.position = Vector2(0, 14)
			elif scn == "catch_net":
				ic.position = Vector2(0, 4)
				ic.scale = Vector2(0.45, 0.45)
			elif scn == "booster":
				ic.end_offset = Vector2(34, -12)
				ic.position = Vector2(-17, 8)
			elif scn == "deflector":
				ic.position = Vector2(0, -2)
			elif scn == "flap_sorter":
				ic.end_offset = Vector2(80, 20)
				ic.position = Vector2(-20, -6)
				ic.scale = Vector2(0.5, 0.5)
			elif scn == "vortex":
				ic.position = Vector2(0, -10)
				ic.scale = Vector2(0.32, 0.32)
			elif scn == "plunger":
				ic.position = Vector2(0, 8)
				ic.scale = Vector2(0.6, 0.6)
			elif scn == "chime":
				ic.end_offset = Vector2(34, 10)
				ic.position = Vector2(-17, -2)
			elif scn == "felt_chute":
				ic.end_offset = Vector2(34, 12)
				ic.position = Vector2(-17, -4)
			elif scn == "cannon":
				ic.position = Vector2(-4, 16)
				ic.scale = Vector2(0.7, 0.7)
			elif scn == "dispenser":
				ic.position = Vector2(0, 12)
				ic.scale = Vector2(0.6, 0.6)
			elif scn == "goal_cup":
				ic.position = Vector2(0, 12)
				ic.scale = Vector2(0.6, 0.6)
			elif scn == "loop":
				ic.position = Vector2(0, 8)
				ic.scale = Vector2(0.4, 0.4)
			elif scn == "jump":
				ic.end_offset = Vector2(34, 2)
				ic.position = Vector2(-20, 2)
				ic.scale = Vector2(0.6, 0.6)
			art.add_child(ic)
		37:
			for k in 3:
				_part(art, S + "domino.png", Rect2(), Vector2(-14 + k * 10, -14))
		36:
			_part(art, S + "engine.png", Rect2(0, 0, 56, 48), Vector2(-28, -24))
		35:
			_part(art, S + "barricade.png", Rect2(0, 0, 18, 30), Vector2(-9, -15))
		34:
			_part(art, S + "dock.png", Rect2(), Vector2(-20, -8))
			_part(art, S + "drone.png", Rect2(0, 0, 22, 16), Vector2(-11, -26))
		33:
			_part(art, S + "timer.png", Rect2(), Vector2(-10, -17))
		32:
			_part(art, S + "sentry.png", Rect2(0, 0, 40, 40), Vector2(-20, -20))
		31:
			_part(art, S + "lantern.png", Rect2(0, 0, 16, 22), Vector2(-8, -11))
		30:
			_part(art, S + "borer.png", Rect2(0, 0, 40, 28), Vector2(-20, -14))
		29:
			_part(art, S + "plate.png", Rect2(0, 0, 26, 8), Vector2(-13, -4))
		28:
			var tw: Node2D = preload("res://scenes/tripwire.gd").new()
			tw.set_meta("ghost", true)
			tw.set_meta("icon", true)
			tw.end_offset = Vector2(26, -6)
			tw.position = Vector2(-13, 0)
			art.add_child(tw)
		27:
			_part(art, S + "snare.png", Rect2(72, 0, 36, 20), Vector2(-18, -10))
		26:
			_part(art, S + "keg.png", Rect2(0, 0, 22, 26), Vector2(-11, -13))
		25:
			var tb: Node2D = preload("res://scenes/tube.gd").new()
			tb.set_meta("ghost", true)
			tb.end_offset = Vector2(26, -10)
			tb.position = Vector2(-13, 6)
			tb.scale = Vector2(0.8, 0.8)
			art.add_child(tb)
		24:
			_part(art, S + "seesaw_base.png", Rect2(), Vector2(-14, -6))
			_part(art, S + "seesaw_plank.png", Rect2(), Vector2(-38, -16))
		23:
			_part(art, S + "harpoon_base.png", Rect2(), Vector2(-24, -20))
			_part(art, S + "harpoon_bow.png", Rect2(), Vector2(-10, -16))
		22:
			_part(art, S + "magnet.png", Rect2(36, 0, 36, 40), Vector2(-18, -20))
		21:
			_part(art, S + "crusher.png", Rect2(0, 0, 52, 40), Vector2(-26, -20))
		20:
			_part(art, S + "trapdoor_frame.png", Rect2(), Vector2(-28, -4))
			_part(art, S + "trapdoor_leaf.png", Rect2(), Vector2(-24, -4))
			_part(art, S + "trapdoor_leaf.png", Rect2(), Vector2(0, -4), true)
		19:
			_part(art, S + "flamer.png", Rect2(0, 0, 44, 48), Vector2(-22, -24))
			_part(art, S + "flamer_nozzle.png", Rect2(), Vector2(2, -3))
		18:
			_part(art, S + "tesla.png", Rect2(0, 0, 40, 70), Vector2(-20, -35))
		17:
			_part(art, S + "lab.png", Rect2(0, 0, 48, 58), Vector2(-24, -29))
		16:
			_part(art, S + "assembler.png", Rect2(0, 0, 48, 60), Vector2(-24, -30))
		15:
			_part(art, S + "wheel_stand.png", Rect2(), Vector2(-25, -6))
			_part(art, S + "gravity_wheel.png", Rect2(), Vector2(-33, -33))
		14:
			_part(art, S + "pendulum_hub.png", Rect2(), Vector2(-8, -30))
			_part(art, S + "wrecking_ball.png", Rect2(), Vector2(-13, -8))
		13:
			_part(art, S + "bellows.png", Rect2(0, 0, 36, 24), Vector2(-12, -12))
		8:
			_part(art, S + "catapult_base.png", Rect2(), Vector2(-18, -12))
			_part(art, S + "catapult_arm.png", Rect2(), Vector2(-4, -6))
		9, 10, 11, 12:
			var n: Node2D = load(["res://scenes/chute.tscn", "res://scenes/splitter.tscn", "res://scenes/bumper.tscn", "res://scenes/belt.tscn"][t - 9]).instantiate()
			n.set_meta("ghost", true)   # no physics, just the drawing
			n.set_process_input(false)
			if t == 9:
				n.end_offset = Vector2(56, 24)
				n.position = Vector2(-28, -12)
			elif t == 12:
				n.end_offset = Vector2(56, -16)
				n.position = Vector2(-28, 8)
			art.add_child(n)
	# fit: small pieces at 1:1 (crisp), big ones scaled down smoothly
	var box := _bounds(art)
	var k := minf(1.0, minf(ICON_BOX.x / box.size.x, ICON_BOX.y / box.size.y))
	if t == 7:
		k = 2.0   # spikes are tiny: show them at 2x
	elif t == 10:
		k = 1.3
	elif t == 11:
		k = 1.4
	art.scale = Vector2(k, k)
	art.position = -box.get_center() * k
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if k >= 1.0 else CanvasItem.TEXTURE_FILTER_LINEAR


func _bounds(art: Node2D) -> Rect2:
	var r := Rect2()
	var first := true
	for c in art.get_children():
		var cr: Rect2
		if c is Sprite2D:
			var sz: Vector2 = c.region_rect.size if c.region_enabled else c.texture.get_size()
			cr = Rect2(c.position, sz)
		elif c is Line2D:
			cr = Rect2(c.points[0], Vector2(20, 5))
		elif c.has_method("_on_touch"):
			cr = Rect2(c.position + Vector2(-11, -27), Vector2(22, 27))
		elif "end_offset" in c:
			cr = Rect2(c.position + Vector2(0, minf(0.0, c.end_offset.y) - 8), Vector2(56, absf(c.end_offset.y) + 12))
		else:
			cr = Rect2(c.position + Vector2(-18, -18), Vector2(36, 26))
		r = cr if first else r.merge(cr)
		first = false
	return r
