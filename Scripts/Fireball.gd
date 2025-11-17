extends "res://Scripts/Thunderbolt.gd"

## Fireball projectile - Big burst damage on impact, no DoT

# Override to disable DoT behavior
const FIREBALL_MODE = true  # Flag to change behavior

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material for trailing fire embers."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Particle behavior - scatter in all directions with more drift
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 30.0
	particle_mat.initial_velocity_max = 100.0
	particle_mat.gravity = Vector3(0, 50, 0)  # Slight upward drift for heat effect
	
	# Fade and scale over lifetime
	particle_mat.scale_min = 0.3
	particle_mat.scale_max = 0.6
	
	# Enable rotation flags
	particle_mat.particle_flag_disable_z = true
	particle_mat.particle_flag_align_y = false
	particle_mat.particle_flag_rotate_y = false
	
	# Random initial rotation for each particle
	particle_mat.angle_min = 0.0
	particle_mat.angle_max = 360.0
	
	# Random spinning motion over time
	particle_mat.angular_velocity_min = -180.0
	particle_mat.angular_velocity_max = 180.0
	
	return particle_mat

func _setup_enhanced_vfx() -> void:
	"""Create fire-themed visual effects."""
	
	# Setup additive blending for glowing effect
	_setup_additive_materials()
	
	# Animate the outer glow with fire colors
	if outer_glow:
		var glow_scale_tween = create_tween()
		glow_scale_tween.set_loops()
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.85, 0.12), 0.15)
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.7, 0.10), 0.15)
	
	# Pulsing glow on the core with orange tint
	if core_glow:
		var core_tween = create_tween()
		core_tween.set_loops()
		core_tween.tween_property(core_glow, "scale", Vector2(0.12, 0.18), 0.2)
		core_tween.tween_property(core_glow, "scale", Vector2(0.09, 0.15), 0.2)
	
	# Color shift for main projectile - fire colors
	if main_bolt:
		var color_tween = create_tween()
		color_tween.set_loops()
		color_tween.tween_property(main_bolt, "modulate", Color(1.0, 0.7, 0.2), 0.3)
		color_tween.tween_property(main_bolt, "modulate", Color(1.0, 0.5, 0.15), 0.3)
	
	# Add trailing fire particles with smoke texture
	particles = GPUParticles2D.new()
	add_child(particles)
	particles.amount = 40
	particles.lifetime = 0.5
	particles.emitting = true
	particles.local_coords = false
	particles.process_material = _create_particle_material()
	particles.z_index = -1
	# Use smoke/flame particle instead of spark
	particles.texture = preload("res://Assets/Sprites/Particles/smoke_01.png")
	# Color the particles orange/red for fire
	particles.modulate = Color(1.0, 0.5, 0.2, 0.8)

func _attach_to_target(target) -> void:
	"""Override: Fireball does big burst damage instead of DoT."""
	is_attached = true
	attached_target = target
	velocity = Vector2.ZERO
	
	# Stop the lifetime timer
	var lifetime_timer = $Lifetime
	if lifetime_timer:
		lifetime_timer.stop()
	
	if particles:
		particles.emitting = false
	
	# Deal BIG damage all at once (3x the normal amount)
	if attached_target.has_method("take_damage"):
		attached_target.take_damage(damage * 3, global_position, "hit_effect", "fire")
	
	_play_attachment_effect()
	
	# Destroy immediately after hit
	await get_tree().create_timer(0.1).timeout
	_destroy()
