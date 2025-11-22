extends Area2D

## Elemental imbue power-up - adds element to melee attacks

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var particles: GPUParticles2D = $GPUParticles2D

var collected: bool = false
var duration: float = 30.0  # How long the buff lasts

func _ready() -> void:
	# Update sprite color based on player's skill
	_update_element_display()
	_setup_particle_material()
	_play_idle_animation()

func _update_element_display() -> void:
	"""Update color and label based on player's skill."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var skill = player.current_skill if "current_skill" in player else ""
	
	match skill:
		"thunderbolt":
			sprite.modulate = Color(0.6, 0.9, 1.0, 1.0)  # Cyan
			label.text = "⚡ LIGHTNING"
			label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1.0))
		"fireball":
			sprite.modulate = Color(1.0, 0.5, 0.2, 1.0)  # Orange
			label.text = "🔥 FIRE"
			label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1.0))
		"icelance":
			sprite.modulate = Color(0.4, 0.8, 1.0, 1.0)  # Light blue
			label.text = "❄️ ICE"
			label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
		_:
			# No skill chosen or unknown
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
			label.text = "ELEMENTAL"
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

func _setup_particle_material() -> void:
	"""Setup the particle burst effect material based on element."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Burst outward in all directions
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 250.0
	particle_mat.gravity = Vector3(0, 100, 0)
	
	# Size and fade
	particle_mat.scale_min = 0.4
	particle_mat.scale_max = 1.0
	
	# Color based on element (match the sprite color)
	particle_mat.color = sprite.modulate
	
	particles.process_material = particle_mat
	particles.texture = sprite.texture

func _play_idle_animation() -> void:
	"""Spinning and glowing animation."""
	# Spinning
	var spin_tween = create_tween()
	spin_tween.set_loops()
	spin_tween.tween_property(sprite, "rotation", TAU, 3.0).set_ease(Tween.EASE_IN_OUT)
	
	# Bobbing up and down (wait a frame to ensure position is set)
	await get_tree().process_frame
	var start_y = position.y
	var bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", start_y - 10, 1.5).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(self, "position:y", start_y + 10, 1.5).set_ease(Tween.EASE_IN_OUT)
	
	# Pulsing glow
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate:a", 0.7, 1.0)
	glow_tween.tween_property(sprite, "modulate:a", 1.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	
	if body.name == "Player" or body.is_in_group("player") or body is CharacterBody2D:
		_collect(body)

func _collect(player: Node2D) -> void:
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Apply elemental imbue to player
	if player.has_method("apply_elemental_imbue"):
		player.apply_elemental_imbue(duration)
	
	_play_collection_effect()
	
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_collection_effect() -> void:
	# Flash and scale up
	var collect_tween = create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(sprite, "scale", Vector2(2.5, 2.5), 0.3)
	collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	collect_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	
	# Burst particles
	if particles:
		particles.emitting = true
