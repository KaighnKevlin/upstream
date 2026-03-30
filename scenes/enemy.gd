extends CharacterBody2D

@export var speed: float = 60.0
@export var hp: int = 3
@export var damage: int = 10

var direction: float = -1.0  # -1 = moving left toward dome

const GRAVITY := 980.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	velocity.x = speed * direction
	move_and_slide()


func take_damage(amount: int) -> void:
	hp -= amount
	var sprite := $Sprite as Polygon2D
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		queue_free()
