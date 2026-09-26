extends CanvasLayer
## The field manual (F1): what every building, enemy, item and event does,
## one line each, in three tabs. F1, Esc or a click outside closes it.

const PixelFont = preload("res://scripts/pixel_font.gd")
const SFX = preload("res://scripts/sfx.gd")

const TEXT := Color(0.95, 0.88, 0.7)
const DIM := Color(0.72, 0.66, 0.52)
const KEYC := Color(0.55, 0.88, 0.92)

const TABS := [
	["BUILDINGS", [
		["1", "Trampoline", "bounces anything that lands on it; drag its handle to set angle and force"],
		["2", "Vein tapper", "on a dug-out ore block: flings copper or iron ore; drag to aim"],
		["3", "Laser smelter", "ore flying through the beam melts into an ingot"],
		["4", "Upstream lift", "carries items up; build on its top to extend; click the cap to spill"],
		["5", "Drop hopper", "holds ore and dumps it on enemies walking underneath"],
		["6", "Funnel turret", "fires whatever ore you feed it at enemies in range"],
		["7", "Spikes", "hurt anything that falls or walks onto them"],
		["8", "Catapult", "catches items in its bucket and lobs them; drag to aim"],
		["9", "Chute", "drag top to bottom: a sloped rail that ore slides down"],
		["0", "Splitter", "alternates items left and right; click for left/right only"],
		["C", "Conveyor belt", "drag out: carries items along; faster when powered"],
		["", "Pneumatic tube", "drag funnel to nozzle: sucks items in and shoots them out, any way"],
		["", "Seesaw", "drop something heavy on one end to fling what sits on the other"],
		["V", "Bellows fan", "an aimed air stream that carries light items and buffets fliers"],
		["B", "Bumper", "kicks items and enemies away hard"],
		["M", "Wrecking pendulum", "ore knocks it swinging; it smashes walkers"],
		["N", "Gravity wheel", "falling ore turns it; powers machines nearby"],
		["T", "Assembler", "turns ingots into shot, gears, flasks, springs, blast shells; click: recipe"],
		["R", "Crusher", "grinds ore to grit; chews anything standing on its rollers"],
		["Y", "Research lab", "feed it science flasks; click it for the research screen"],
		["U", "Tesla coil", "fed ingots: chain lightning, reaches through rock"],
		["I", "Flame turret", "burns ore as fuel; sets packs alight and smelts ore in flight"],
		["", "Harpoon ballista", "anti-air, fed scrap or iron ingots: hooks fliers and drags them down"],
		["X", "Trapdoor", "turf over a pit: drops walkers in; bridgers and masons don't see it"],
		["Z", "Electromagnet", "pulses: lifts iron and light walkers, then slams them down"],
	]],
	["ENEMIES", [
		["", "Titan", "slow, tough axe-wielder; leaps out of ditches; stomps"],
		["", "Scuttler", "fast beetle that crawls up walls and blows itself up on the dome"],
		["", "Soldier", "spear automaton; plants siege ladders at ditches"],
		["", "Shieldbearer", "tower shield turns light ore aside from the front; hit it from above"],
		["", "Caster", "hovers at range and shoots bolts"],
		["", "Ornithopter", "flier that drops bombs as it passes"],
		["", "Magpie", "steals loose ore and flies off with it"],
		["", "Sapper", "tunnels under your defences to breach the dome; only lightning reaches it"],
		["", "Bridge engine", "lays a bridge across a ditch for the pack; snap it with iron"],
		["", "Mason", "bricks your ditches in with stone"],
		["", "Tinker", "fragile repair crew that welds its friends back up: kill it first"],
		["", "Troop airship", "flies over everything and lowers soldiers behind your lines"],
		["", "Foundry Engine", "boss every 5th wave: flings slag, spawns scuttlers, bulldozes ditches"],
		["", "Gilded", "from wave 6: gold elites with double health and double loot"],
	]],
	["ITEMS AND EVENTS", [
		["", "Copper ore", "light and bouncy: the basic ammo and ingot"],
		["", "Iron ore", "heavy: hits harder, punches through shields"],
		["", "Ingots", "smelted ore: dome ammo, tesla charge, assembler input"],
		["", "Iron shot", "dense ammo from the assembler"],
		["", "Springsteel", "ricochets through a whole line of enemies"],
		["", "Blast shell", "explodes on impact; sets off other shells nearby"],
		["", "Gear / flask", "assembler parts; flasks are science for the lab"],
		["", "Grit", "crushed ore: three light chips per ore; shell filling"],
		["", "Scrap", "what's left of a wrecked automaton: melt it, grind it, fire it"],
		["", "Salvage cache", "strongboxes hidden in caves: walk into one for loot"],
		["", "Meteor shower", "burning ore falls from the sky (F6 in sandbox)"],
		["", "Thunderstorm", "lightning seeks tall metal and charges tesla coils (F7)"],
		["Shift", "Grappling hook", "reel up walls, yank enemies, drag loot back"],
		["", "Keys", "Tab/wheel: pick a piece  RMB: remove  L: light  F8: music"],
	]],
]

var _tab := 0
var _root: Control


func _ready() -> void:
	layer = 7
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)


func toggle() -> void:
	visible = not visible
	if visible:
		_build()
	SFX.play(self, SFX.sfx_clink())


func _label(text: String, at: Vector2, size: int, color: Color, width: float) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = at
	l.size = Vector2(width, size + 4)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)


func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(80 + i * 190, 58), Vector2(180, 26))


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var p := NinePatchRect.new()
	p.texture = preload("res://assets/ui/panel.png")
	p.patch_margin_left = 8
	p.patch_margin_top = 8
	p.patch_margin_right = 8
	p.patch_margin_bottom = 8
	p.position = Vector2(60, 24)
	p.size = Vector2(1160, 600)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_label("FIELD MANUAL", Vector2(80, 32), 20, TEXT, 400)
	_label("F1 closes", Vector2(1080, 38), 10, DIM, 120)
	for i in TABS.size():
		var r := _tab_rect(i)
		var bg := ColorRect.new()
		bg.position = r.position
		bg.size = r.size
		bg.color = Color(0.52, 0.41, 0.27) if i == _tab else Color(0.2, 0.16, 0.12)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bg)
		_label(TABS[i][0], r.position + Vector2(10, 7), 10, TEXT, r.size.x - 12)
	var entries: Array = TABS[_tab][1]
	var per_col := int(ceil(entries.size() / 2.0))
	var row_h := minf(40.0, 510.0 / per_col)
	for k in entries.size():
		var e: Array = entries[k]
		var col := k / per_col
		var row := k % per_col
		var at := Vector2(80 + col * 560, 96 + row * row_h)
		if e[0] != "":
			_label(e[0], at, 10, KEYC, 50)
		_label(e[1], at + Vector2(52, 0), 10, TEXT, 200)
		_label(e[2], at + Vector2(52, 14), 10, DIM, 500)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in TABS.size():
			if _tab_rect(i).has_point(event.position):
				_tab = i
				_build()
				get_viewport().set_input_as_handled()
				return
		if not Rect2(Vector2(60, 24), Vector2(1160, 600)).has_point(event.position):
			toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
