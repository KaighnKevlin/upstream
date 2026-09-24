extends Node

# Miner walking sheet: 48x32, 2 columns x 1 row, 24x32 per frame
# Frame 0: idle, Frame 1: walking


## The prospector (tools/art/gen_player.py): 32x40 frames, body centred.
## Returns null if the sheet is missing so the caller can fall back.
static func create_prospector_frames() -> SpriteFrames:
	var tex := load("res://assets/sprites/prospector.png") as Texture2D
	if tex == null:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add_frames(sf, tex, "idle", [0, 1, 2, 3], 32, 40, 5.0)
	_add_frames(sf, tex, "walk", [4, 5, 6, 7, 8, 9, 10, 11], 32, 40, 14.0)
	_add_frames(sf, tex, "jump", [12, 13], 32, 40, 6.0)
	_add_frames(sf, tex, "attack", [0], 32, 40, 4.0)
	# pickaxe swing: raise, strike, follow-through — about one mine_cooldown
	_add_frames(sf, tex, "mine", [14, 15, 16], 32, 40, 16.0)
	sf.set_animation_loop("mine", false)
	sf.set_animation_loop("jump", false)
	return sf


static func create_player_frames() -> SpriteFrames:
	var tex := load("res://assets/sprites/player-miner-walking-sheet.png") as Texture2D
	if tex == null:
		return null

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var fw := 24
	var fh := 32

	# Idle: frame 0
	_add_frames(sf, tex, "idle", [0], fw, fh, 4.0)

	# Walk: the 6-frame run cycle if it's there, else walking frame + idle
	var run := load("res://assets/sprites/player_miner_run.png") as Texture2D
	if run:
		_add_frames(sf, run, "walk", [0, 1, 2, 3, 4, 5], fw, fh, 11.0)
	else:
		_add_frames(sf, tex, "walk", [1, 0], fw, fh, 6.0)

	# Jump: use frame 1 (walking pose works for airborne)
	_add_frames(sf, tex, "jump", [1], fw, fh, 4.0)

	# Attack: use frame 1
	_add_frames(sf, tex, "attack", [0, 1], fw, fh, 8.0)

	return sf


static func _add_frames(sf: SpriteFrames, tex: Texture2D, name: String,
		cols: Array, fw: int, fh: int, speed: float) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, speed)
	sf.set_animation_loop(name, true)

	for col in cols:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * fw, 0, fw, fh)
		atlas.filter_clip = true
		sf.add_frame(name, atlas)
