extends Node2D

## Training dummy that reacts to hits

@onready var visual_root: Node2D = $VisualRoot
@onready var hitstop_timer: Timer = $HitstopTimer
@onready var dummy_sprite: AnimatedSprite2D = $Dummy

var in_hitstop: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var base_position: Vector2 = Vector2.ZERO

const HITSTOP_DURATION: float = 0.08
const KNOCKBACK_STRENGTH: float = 30.0
const RETURN_SPEED: float = 8.0

# Damage number scene
const DamageNumber = preload("res://Scenes/DamageNumber.tscn")

func _ready() -> void:
	base_position = visual_root.position
	
	# Show dummy and start with idle animation
	if dummy_sprite:
		dummy_sprite.visible = true
		if dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("idle"):
			dummy_sprite.play("idle")

func _process(delta: float) -> void:
	if in_hitstop:
		return
	
	# Apply knockback and return to center
	if knockback_velocity.length() > 0.1:
		visual_root.position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 5.0)
	
	# Return to base position
	if visual_root.position.distance_to(base_position) > 0.5:
		visual_root.position = visual_root.position.lerp(base_position, delta * RETURN_SPEED)
	else:
		visual_root.position = base_position

func take_damage(damage: int, hit_animation: String = "hit_effect") -> void:
	# Spawn floating damage number
	_spawn_damage_number(damage)
	
	# Play hit effect animation
	play_hit_effect(hit_animation)
	
	# Apply knockback
	knockback_velocity = Vector2(KNOCKBACK_STRENGTH, 0)
	
	# Visual feedback - shake and scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector2(0.9, 1.1), 0.05)
	tween.tween_property(visual_root, "rotation", 0.1, 0.05)
	tween.chain().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector2.ONE, 0.15)
	tween.tween_property(visual_root, "rotation", 0.0, 0.15)
	
	# Start hitstop
	_start_hitstop()

func _spawn_damage_number(damage: int) -> void:
	var damage_num = DamageNumber.instantiate()
	get_parent().add_child(damage_num)
	
	# Position above the dummy with some randomness
	var spawn_offset = Vector2(randf_range(-30, 30), randf_range(-100, -50))
	damage_num.global_position = global_position + spawn_offset
	
	# Put damage numbers on top of everything
	damage_num.z_index = 100
	
	# Set color based on damage amount
	var color = Color.WHITE
	if damage >= 30:
		color = Color.ORANGE_RED  # Big hits are red/orange
	elif damage >= 20:
		color = Color.YELLOW  # Medium hits are yellow
	
	damage_num.setup(damage, color)

func _start_hitstop() -> void:
	in_hitstop = true
	hitstop_timer.wait_time = HITSTOP_DURATION
	hitstop_timer.start()

func play_hit_effect(animation_name: String = "hit_effect") -> void:
	"""Play a hit effect animation. Scalable for different attack types."""
	if not dummy_sprite:
		return  # No dummy sprite node, skip
	
	# Check if animation exists
	if not dummy_sprite.sprite_frames:
		return
	
	if not dummy_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Hit effect animation '" + animation_name + "' not found!")
		return
	
	# Play the hit effect
	dummy_sprite.play(animation_name)
	
	# Return to idle when effect finishes
	if not dummy_sprite.animation_finished.is_connected(_on_hit_effect_finished):
		dummy_sprite.animation_finished.connect(_on_hit_effect_finished)

func _on_hit_effect_finished() -> void:
	"""Return to idle animation after hit effect completes."""
	if dummy_sprite and dummy_sprite.sprite_frames:
		# Go back to idle animation
		if dummy_sprite.sprite_frames.has_animation("idle"):
			dummy_sprite.play("idle")

func _on_hitstop_timer_timeout() -> void:
	in_hitstop = false
