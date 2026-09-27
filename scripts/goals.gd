extends Node
## Survival's goals: a chain shown in the HUD panel, each ticked off when it
## happens. The first five walk a new player through the core loop (find
## ore, tap it, smelt it, feed the dome, defend); the rest lead on into the
## wider game (waves, research, allies, the buried vault, a boss), and each
## of those drops a supply crate by the dome. Only in survival.

const WorldGen = preload("res://scripts/world_gen.gd")
const SFX = preload("res://scripts/sfx.gd")

const GOALS := [
	["Dig down (J) to find ore", "_found_ore"],
	["Put a vein tapper (2) on it", "_has_tapper"],
	["Smelt: a laser (3) in its path", "_has_ingot"],
	["Ingot into the dome: waves begin", "_dome_fed"],
	["Build a funnel turret (6)", "_has_turret"],
	["Hold out to wave 4", "_wave_4", true],
	["Research a tech (lab Y + flasks)", "_researched", true],
	["Set down a brass sentry", "_has_sentry", true],
	["Find the buried vault (dig deep)", "_found_vault", true],
	["Open the vault's relic chest", "_opened_vault", true],
	["Beat the Foundry (wave 5)", "_wave_6", true],
]

var step := 0
var _label: Label
var _check := 0.0


func _ready() -> void:
	var main := get_parent()
	_label = main._hud_label("", 16, Color(0.55, 0.88, 0.92))
	_label.position = Vector2(24, 66)
	_label.size = Vector2(340, 20)
	main.get_node("CanvasLayer").add_child(_label)
	_show()


func _show() -> void:
	_label.text = "GOAL: " + GOALS[step][0] if step < GOALS.size() else ""


func _process(delta: float) -> void:
	_label.visible = get_parent()._build_mode_label.text == ""   # shares a line with "Build: ..."
	if step >= GOALS.size():
		return
	_check -= delta
	if _check > 0:
		return
	_check = 0.3
	if call(GOALS[step][1]):
		var main := get_parent()
		if main.has_method("_show_banner"):
			main._show_banner("GOAL DONE", GOALS[step][0] + ("  -  a supply crate by the dome" if GOALS[step].size() > 2 else ""))
		SFX.play(main, SFX.sfx_ammo_received())
		if GOALS[step].size() > 2:
			_supply_crate()
		step += 1
		_show()


func _buildings(script_name: String) -> bool:
	var bs := get_node_or_null("/root/BuildSystem")
	if bs == null:
		return false
	for b in bs._placed_buildings:
		if is_instance_valid(b) and b.get_script() and b.get_script().resource_path.get_file() == script_name:
			return true
	return false


func _found_ore() -> bool:
	var main := get_parent()
	var p := main.get_node_or_null("Player") as Node2D
	var tm := main.get_node_or_null("TileMapLayer") as TileMapLayer
	if p == null or tm == null:
		return false
	var c := tm.local_to_map(tm.to_local(p.global_position))
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var t := tm.get_cell_atlas_coords(c + Vector2i(dx, dy)).x
			if tm.get_cell_source_id(c + Vector2i(dx, dy)) != -1 and t in [WorldGen.TILE_IRON, WorldGen.TILE_COPPER]:
				return true
	return false


func _has_tapper() -> bool:
	return _buildings("miner.gd")


func _has_ingot() -> bool:
	return not get_tree().get_nodes_in_group("ingots").is_empty() or get_parent()._receiver.buffer > 0


func _dome_fed() -> bool:
	return get_parent()._waves_started


func _has_turret() -> bool:
	return _buildings("funnel_turret.gd")


func _wave_4() -> bool:
	return get_parent().wave_number >= 4


func _wave_6() -> bool:
	return get_parent().wave_number >= 6


func _researched() -> bool:
	for t in preload("res://scripts/tech.gd").TECHS:
		if preload("res://scripts/tech.gd").level(t.id) > 0:
			return true
	return false


func _has_sentry() -> bool:
	return _buildings("sentry.gd")


func _found_vault() -> bool:
	var ruin := get_parent().get_node_or_null("Ruins")
	var p := get_parent().get_node_or_null("Player") as Node2D
	return ruin != null and p != null and ruin.room.grow(48).has_point(p.global_position)


func _opened_vault() -> bool:
	for c in get_tree().get_nodes_in_group("caches"):
		if c.get("relic") and c.opened:
			return true
	return false


## A reward: a salvage crate comes down beside the dome on a little
## parachute and lands with a thump, ready to be walked into.
var crates := 0          # tests

func _supply_crate() -> void:
	var main := get_parent()
	var dome := main.get_node_or_null("DomeZone") as Node2D
	var x: float = (dome.global_position.x if dome else 1200.0) + float([-1, 1].pick_random()) * randf_range(110, 170)
	var ground := float(WorldGen.SURFACE_ROWS * WorldGen.TILE_SIZE)
	var c: Node2D = load("res://scenes/cache.tscn").instantiate()
	c.global_position = Vector2(x, ground - 260)
	main.add_child(c)
	crates += 1
	var chute := Node2D.new()
	chute.draw.connect(func():
		chute.draw_arc(Vector2(0, -40), 16, PI, TAU, 12, Color(0.85, 0.8, 0.7), 3.0)
		for sx in [-15, 0, 15]:
			chute.draw_line(Vector2(sx, -40 if sx == 0 else -41), Vector2(sx * 0.4, -18), Color(0.6, 0.55, 0.5), 1.0))
	c.add_child(chute)
	var tw := c.create_tween()
	tw.tween_property(c, "global_position:y", ground, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		chute.queue_free()
		preload("res://scripts/fx.gd").burst(main, Vector2(x, ground), Color(0.55, 0.45, 0.35, 0.8), 8, 50.0, 0.4, 1.8)
		SFX.play_small(c, SFX.sfx_ore_knock("ground"), -4.0, 0.7))
