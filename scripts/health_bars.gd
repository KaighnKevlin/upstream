extends Node2D
## Small health bars under enemies that have been hit in the last few seconds
## (FX.recent_hits), fading out after. Bosses have their own big bars and are
## skipped.

const FX = preload("res://scripts/fx.gd")
const SHOW_MS := 3000
const FADE_MS := 600

var _full := {}          # enemy -> full health (the most it has been seen with)


func _ready() -> void:
	z_index = 11
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # the night mustn't darken the bars
	material = m


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var now := Time.get_ticks_msec()
	for e in FX.recent_hits.keys():
		var age: int = now - int(FX.recent_hits[e])
		if not is_instance_valid(e) or age > SHOW_MS or ("_dying" in e and e._dying):
			FX.recent_hits.erase(e)
			_full.erase(e)
			continue
		var f = e.get_script().resource_path.get_file() if e.get_script() else ""
		if f in ["foundry.gd", "dreadnought.gd"]:
			continue
		var hp: float = float(e.get("hp")) if e.get("hp") != null else 0.0
		var full = e.get("max_hp") if e.get("max_hp") != null else e.get("MAX_HP")
		_full[e] = maxf(_full.get(e, hp), float(full) if full != null else hp)
		var frac := clampf(hp / maxf(1.0, _full[e]), 0.0, 1.0)
		var alpha := clampf(float(SHOW_MS - age) / FADE_MS, 0.0, 1.0)
		var c: Vector2 = e.hit_center() if e.has_method("hit_center") else e.global_position
		var r: float = e.hit_radius() if e.has_method("hit_radius") else 12.0
		var w := clampf(r * 1.6, 16.0, 40.0)
		# under the feet for walkers, under the body for fliers
		var base: Vector2 = Vector2(e.global_position.x, e.global_position.y + 16.0) if e is CharacterBody2D else c + Vector2(0, r + 6.0)
		var at := to_local(base + Vector2(-w * 0.5, 0))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, 5)), Color(0.08, 0.06, 0.05, 0.85 * alpha))
		var col := Color(0.45, 0.85, 0.4) if frac > 0.5 else (Color(0.9, 0.75, 0.3) if frac > 0.25 else Color(0.9, 0.3, 0.2))
		col.a = alpha
		draw_rect(Rect2(at, Vector2(w * frac, 3)), col)
