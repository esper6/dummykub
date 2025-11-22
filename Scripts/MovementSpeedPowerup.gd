extends Area2D

## Movement Speed Boost power-up - permanently increases movement speed

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var particles: GPUParticles2D = $GPUParticles2D

var collected: bool = false
var speed_multiplier: float = 1.5  # 50% speed increase

func _ready() -> void:
	# Generate weighted random speed multiplier (1.3x to 2.0x)
	speed_multiplier = _get_weighted_multiplier()
	
	# Update label to show the multiplier
	label.text = "%.1fx SPD" % speed_multiplier
	
	# Set color based on tier (higher = more cyan/blue)
	var tier_ratio = (speed_multiplier - 1.3) / (2.0 - 1.3)  # 0.0 to 1.0
	sprite.modulate = Color(0.3 + tier_ratio * 0.4, 0.8 + tier_ratio * 0.2, 1.0)  # Cyan to bright blue
	
	# Setup particle material
	_setup_particle_material()
	
	# Animate
	_play_idle_animation()

func _get_weighted_multiplier() -> float:
	"""Generate a weighted random multiplier from 1.3x to 2.0x.
	Each tier is 1.2x less likely than the previous tier."""
	
	# Available multipliers (in 0.1 increments)
	var tiers: Array[float] = [1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
	
	# Calculate weights (each tier is 1/1.2 the previous)
	var weights: Array[float] = []
	var weight = 1.0
	for i in range(tiers.size()):
		weights.append(weight)
		weight /= 1.2
	
	# Calculate total weight
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	
	# Pick a random value
	var random_value = randf() * total_weight
	
	# Find which tier it lands in
	var cumulative = 0.0
	for i in range(tiers.size()):
		cumulative += weights[i]
		if random_value <= cumulative:
			return tiers[i]
	
	# Fallback (shouldn't reach here)
	return 1.5

func _setup_particle_material() -> void:
	"""Setup the particle burst effect material - cyan/blue speed particles."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Fast burst outward
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 120.0
	particle_mat.initial_velocity_max = 250.0
	particle_mat.gravity = Vector3(0, 100, 0)
	
	# Size and fade
	particle_mat.scale_min = 0.4
	particle_mat.scale_max = 1.0
	
	# Cyan/blue color
	particle_mat.color = Color(0.3, 0.8, 1.0, 1.0)
	
	particles.process_material = particle_mat
	particles.texture = sprite.texture

func _play_idle_animation() -> void:
	"""Smooth flowing animation to convey speed."""
	# Smooth rotation
	var spin_tween = create_tween()
	spin_tween.set_loops()
	spin_tween.tween_property(sprite, "rotation", TAU, 2.0).set_ease(Tween.EASE_IN_OUT)
	
	# Gentle bobbing (wait a frame to ensure position is set)
	await get_tree().process_frame
	var start_y = position.y
	var bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", start_y - 12, 1.2).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(self, "position:y", start_y + 12, 1.2).set_ease(Tween.EASE_IN_OUT)
	
	# Gentle pulsing glow
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate:a", 0.8, 0.6)
	glow_tween.tween_property(sprite, "modulate:a", 1.0, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	
	if body.name == "Player" or body.is_in_group("player") or body is CharacterBody2D:
		_collect(body)

func _collect(player: Node2D) -> void:
	collected = true
	monitoring = false
	monitorable = false
	
	# Apply permanent movement speed boost to player
	if player.has_method("apply_movement_speed_boost"):
		player.apply_movement_speed_boost(speed_multiplier, 0.0)  # 0.0 duration = permanent
	
	_play_collection_effect()
	
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_collection_effect() -> void:
	# Flash and scale up
	var collect_tween = create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.2)
	collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	collect_tween.tween_property(label, "modulate:a", 0.0, 0.2)
	
	# Burst particles
	if particles:
		particles.emitting = true

