class_name Pointer
extends RefCounted
## Where the mouse is. Game code reads it through here instead of
## get_global_mouse_position(), so the agent playtester
## (tools/scenarios/agent_rec.gd) can point without moving the real cursor:
## it sets `fake` and keeps `screen_pos` (viewport pixels) where its clicks go.

static var fake := false
static var screen_pos := Vector2.ZERO


static func screen(vp: Viewport) -> Vector2:
	return screen_pos if fake else vp.get_mouse_position()


## The mouse in ci's canvas coordinates, like ci.get_global_mouse_position().
static func world(ci: CanvasItem) -> Vector2:
	if not fake:
		return ci.get_global_mouse_position()
	return ci.get_canvas_transform().affine_inverse() * screen_pos
