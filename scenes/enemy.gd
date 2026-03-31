extends CharacterBody2D

@export var speed: float = 60.0
@export var hp: int = 3
@export var damage: int = 10

var direction: float = -1.0  # -1 = moving left toward dome

const GRAVITY := 980.0


const SpriteLoader = preload("res://scripts/sprite_loader.gd")

func _ready() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.sprite_frames = SpriteLoader.create_slime_frames()
		$AnimatedSprite2D.play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	velocity.x = speed * direction
	move_and_slide()

	# Flip sprite based on direction
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = direction > 0


func take_damage(amount: int) -> void:
	hp -= amount
	if has_node("AnimatedSprite2D"):
		var sprite := $AnimatedSprite2D
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		queue_free()
