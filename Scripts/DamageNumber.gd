extends Node2D

## Floating damage number that animates upward and fades out

@onready var label: Label = $Label

var velocity: Vector2 = Vector2(0, -100)  # Float upward
var lifetime: float = 1.0  # How long it lasts
var fade_start: float = 0.5  # When to start fading

func _ready() -> void:
	# Add some random horizontal drift
	velocity.x = randf_range(-30, 30)

func setup(damage: int, color: Color = Color.WHITE) -> void:
	label.text = str(damage)
	label.modulate = color
	
	# Scale based on damage (bigger numbers for bigger hits)
	var scale_factor = 1.0 + (damage / 100.0)
	scale = Vector2.ONE * clamp(scale_factor, 1.0, 2.0)

func _process(delta: float) -> void:
	# Move upward
	position += velocity * delta
	
	# Slow down over time
	velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
	
	# Track lifetime
	lifetime -= delta
	
	# Fade out near the end
	if lifetime < fade_start:
		var alpha = lifetime / fade_start
		label.modulate.a = alpha
	
	# Delete when done
	if lifetime <= 0:
		queue_free()

