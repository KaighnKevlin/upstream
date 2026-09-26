extends Node
## Survival's first steps: a short chain of goals shown in the HUD panel, each
## ticked off when it happens, walking a new player through the core loop
## (find ore, tap it, smelt it, feed the dome, defend). Only in survival.

const WorldGen = preload("res://scripts/world_gen.gd")
const SFX = preload("res://scripts/sfx.gd")

const GOALS := [
	["Dig down (J) to find ore", "_found_ore"],
	["Put a vein tapper (2) on it", "_has_tapper"],
	["Smelt: a laser (3) in its path", "_has_ingot"],
	["Ingot into the dome: waves begin", "_dome_fed"],
	["Build a funnel turret (6)", "_has_turret"],
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
			main._show_banner("GOAL DONE", GOALS[step][0])
		SFX.play(main, SFX.sfx_ammo_received())
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
