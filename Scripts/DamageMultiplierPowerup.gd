extends Area2D

## Damage multiplier power-up with weighted random tiers

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var particles: GPUParticles2D = $GPUParticles2D

var collected: bool = false
var damage_multiplier: float = 1.3

func _ready() -> void:
	# Generate weighted random multiplier (1.3x to 2.1x)
	damage_multiplier = _get_weighted_multiplier()
	
	# Update label to show the multiplier
	label.text = "%.1fx DMG" % damage_multiplier
	
	# Set color based on tier (higher = more orange/red)
	var tier_ratio = (damage_multiplier - 1.3) / (2.1 - 1.3)  # 0.0 to 1.0
	sprite.modulate = Color(1.0, 1.0 - tier_ratio * 0.5, 0.2)  # White to orange
	
	# Setup particle material
	_setup_particle_material()
	
	# Animate
	_play_idle_animation()

func _get_weighted_multiplier() -> float:
	"""Generate a weighted random multiplier from 1.3x to 2.1x.
	Each tier is 1.2x less likely than the previous tier."""
	
	# Available multipliers (in 0.1 increments)
	var tiers: Array[float] = [1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1]
	
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
	return 1.3

func _setup_particle_material() -> void:
	"""Setup the particle burst effect material."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Burst outward in all directions
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 200.0
	particle_mat.gravity = Vector3(0, 200, 0)  # Slight downward pull
	
	# Size and fade
	particle_mat.scale_min = 0.3
	particle_mat.scale_max = 0.8
	
	# Color - golden/orange sparkles
	particle_mat.color = Color(1.0, 0.8, 0.3, 1.0)
	
	particles.process_material = particle_mat
	particles.texture = sprite.texture  # Use same star texture

func _play_idle_animation() -> void:
	"""Bobbing and glowing animation."""
	# Bobbing up and down (wait a frame to ensure position is set)
	await get_tree().process_frame
	var start_y = position.y
	var bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", start_y - 10, 1.0).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(self, "position:y", start_y + 10, 1.0).set_ease(Tween.EASE_IN_OUT)
	
	# Pulsing glow
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate:a", 0.7, 0.8)
	glow_tween.tween_property(sprite, "modulate:a", 1.0, 0.8)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	
	if body.name == "Player" or body.is_in_group("player") or body is CharacterBody2D:
		_collect(body)

func _collect(player: Node2D) -> void:
	collected = true
	monitoring = false
	monitorable = false
	
	# Apply damage multiplier to player
	if player.has_method("add_damage_multiplier"):
		player.add_damage_multiplier(damage_multiplier)
	elif "damage_multiplier" in player:
		player.damage_multiplier *= damage_multiplier
	
	_play_collection_effect()
	
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_collection_effect() -> void:
	# Flash and scale up
	var collect_tween = create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.3)
	collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	collect_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	
	# Burst particles
	if particles:
		particles.emitting = true

