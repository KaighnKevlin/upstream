extends Node
## Day and night. A full cycle is LENGTH seconds; the clock starts in the
## small hours so the first dawn comes soon. Drives the sky (parallax_bg.gd
## set_daylight) and the surface light band (main.gd's "Moonlight": cool and
## dim by night, warm and brighter by day, within the LIGHT BUDGET).
## Underground it is always dark.

const LENGTH := 480.0            # seconds for a whole day

var clock := 0.18                # 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk
var paused := false


func daylight() -> float:
	return clampf((0.5 - 0.5 * cos(TAU * clock)) * 1.7 - 0.35, 0.0, 1.0)


func warmth() -> float:
	var d := daylight()
	return clampf(1.0 - absf(d - 0.45) * 2.6, 0.0, 1.0) if d > 0.0 and d < 1.0 else 0.0


func _process(delta: float) -> void:
	if not paused:
		clock = fposmod(clock + delta / LENGTH, 1.0)
	apply()


func apply() -> void:
	var scene := get_parent()
	var d := daylight()
	var w := warmth()
	var bg := scene.get_node_or_null("ParallaxBg")
	if bg and bg.has_method("set_daylight"):
		bg.set_daylight(d, w, inverse_lerp(0.22, 0.78, clock))
	var light := scene.get_node_or_null("Moonlight") as PointLight2D
	if light:
		light.energy = lerpf(0.5, 0.8, d)
		light.color = Color(0.7, 0.78, 1.0).lerp(Color(1.0, 0.97, 0.9), d).lerp(Color(1.0, 0.8, 0.6), w * 0.5)
