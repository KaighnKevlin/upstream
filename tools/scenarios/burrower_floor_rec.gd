extends RefCounted
## Burrower coming up through a cave floor (as iron plating sends it: round
## under the end of a run). In the carved cavern (x 930..1650, floor 576): a
## gravity wheel (x 1500). A burrower starts in the rock under the floor
## (1590, 660) and digs up at it: it must climb out of its hole onto the
## floor and reach the wheel, not grind along inside the floor, falling back
## into its own hole.

const MW = preload("res://scripts/marble_works.gd")
const Plating = preload("res://tools/scenarios/plating_rec.gd")


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	await preload("res://scripts/sandbox_showcase.gd").clear(t.main)
	await MW.carve(t.main, false)
	t.main.get_node("Player").global_position = Vector2(300, 60)
	var wheel := MW._piece(t.main, "res://scenes/gravity_wheel.tscn", Vector2(1500, 540))
	var ln: Node2D = preload("res://scenes/lantern.tscn").instantiate()
	ln.global_position = Vector2(1520, 440)
	t.main.add_child(ln)
	var cam: Camera2D = t.main.get_node("Player/Camera2D")
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2.0, 2.0)
	cam.global_position = Vector2(1540, 560)
	await t.wait(0.3)
	var a: Array = await Plating._race(t, wheel, Vector2(1590, 660), "under")
	t.log_line("burrower: from under the floor: reached the wheel in %.1f s (%d tiles dug), standing at y %.0f (the floor is 576)" % [
		a[0], a[1], a[3].global_position.y if is_instance_valid(a[3]) else -1.0])
	await t.wait(1.0)
	await t.shot("burrower_up_through_floor")
	if is_instance_valid(a[3]):
		a[3].take_damage(99)
