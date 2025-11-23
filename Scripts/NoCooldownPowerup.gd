extends Area2D

## No Cooldown power-up - removes all cooldowns for a duration

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var particles: GPUParticles2D = $GPUParticles2D

var collected: bool = false
var duration: float = 15.0  # 15 seconds of no cooldowns

func _ready() -> void:
	_setup_particle_material()
	_play_idle_animation()

func _setup_particle_material() -> void:
	"""Setup the particle burst effect material - energetic green particles."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Fast burst outward
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 150.0
	particle_mat.initial_velocity_max = 300.0
	particle_mat.gravity = Vector3(0, 150, 0)
	
	# Size and fade
	particle_mat.scale_min = 0.5
	particle_mat.scale_max = 1.2
	
	# Energetic green color
	particle_mat.color = Color(0.2, 1.0, 0.6, 1.0)
	
	particles.process_material = particle_mat
	particles.texture = sprite.texture

func _play_idle_animation() -> void:
	"""Fast pulsing and spinning animation to convey speed."""
	# Fast rotation
	var spin_tween = create_tween()
	spin_tween.set_loops()
	spin_tween.tween_property(sprite, "rotation", TAU, 0.5)
	
	# Rapid bobbing (wait a frame to ensure position is set)
	await get_tree().process_frame
	var start_y = position.y
	var bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", start_y - 15, 0.3).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(self, "position:y", start_y + 15, 0.3).set_ease(Tween.EASE_IN_OUT)
	
	# Fast pulsing glow
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate:a", 0.6, 0.2)
	glow_tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	
	# Scale pulse (use base scale, not absolute values)
	var base_scale = sprite.scale
	var scale_tween = create_tween()
	scale_tween.set_loops()
	scale_tween.tween_property(sprite, "scale", base_scale * 1.2, 0.25)
	scale_tween.tween_property(sprite, "scale", base_scale, 0.25)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	
	# Only allow player to collect (not companions)
	if body.name == "Player" or body.is_in_group("player"):
		_collect(body)

func _collect(player: Node2D) -> void:
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Apply no cooldown buff to player
	if player.has_method("apply_no_cooldown"):
		player.apply_no_cooldown(duration)
	
	_play_collection_effect()
	
	await get_tree().create_timer(0.3).timeout
	queue_free()

func _play_collection_effect() -> void:
	# Flash and scale up rapidly (use base scale, not absolute values)
	var base_scale = sprite.scale
	var collect_tween = create_tween()
	collect_tween.set_parallel(true)
	collect_tween.tween_property(sprite, "scale", base_scale * 3.0, 0.2)
	collect_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	collect_tween.tween_property(label, "modulate:a", 0.0, 0.2)
	
	# Burst particles
	if particles:
		particles.emitting = true
