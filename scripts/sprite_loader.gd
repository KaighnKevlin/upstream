extends Node

# Utility for creating SpriteFrames from spritesheets with 16x16 sprites + 2px separation

const CELL_SIZE := 18  # 16px sprite + 2px gap
const SPRITE_SIZE := 16


static func create_frames_from_sheet(texture: Texture2D, animations: Dictionary) -> SpriteFrames:
	# animations = { "walk": { "row": 0, "frames": 4, "speed": 8.0 }, ... }
	var sf := SpriteFrames.new()

	# Remove default animation
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var atlas_tex := texture

	for anim_name in animations:
		var anim: Dictionary = animations[anim_name]
		var row: int = anim["row"]
		var frame_count: int = anim["frames"]
		var speed: float = anim.get("speed", 8.0)
		var loop: bool = anim.get("loop", true)

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, speed)
		sf.set_animation_loop(anim_name, loop)

		for i in frame_count:
			var atlas := AtlasTexture.new()
			atlas.atlas = atlas_tex
			atlas.region = Rect2(
				i * CELL_SIZE, row * CELL_SIZE,
				SPRITE_SIZE, SPRITE_SIZE
			)
			sf.add_frame(anim_name, atlas)

	return sf


static func create_slime_frames() -> SpriteFrames:
	var tex := load("res://assets/sprites/slime.png") as Texture2D
	return create_frames_from_sheet(tex, {
		"idle": {"row": 0, "frames": 4, "speed": 6.0},
		"walk": {"row": 1, "frames": 4, "speed": 8.0},
		"attack": {"row": 2, "frames": 4, "speed": 8.0},
		"jump": {"row": 3, "frames": 3, "speed": 6.0},
		"damage": {"row": 4, "frames": 2, "speed": 8.0, "loop": false},
		"death": {"row": 5, "frames": 4, "speed": 8.0, "loop": false},
	})


static func create_goblin_frames() -> SpriteFrames:
	var tex := load("res://assets/sprites/goblin.png") as Texture2D
	return create_frames_from_sheet(tex, {
		"idle": {"row": 0, "frames": 4, "speed": 6.0},
		"walk": {"row": 5, "frames": 4, "speed": 8.0},
		"attack": {"row": 1, "frames": 4, "speed": 8.0},
		"jump": {"row": 2, "frames": 3, "speed": 6.0},
		"damage": {"row": 3, "frames": 2, "speed": 8.0, "loop": false},
		"death": {"row": 4, "frames": 4, "speed": 8.0, "loop": false},
	})
