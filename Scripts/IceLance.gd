extends "res://Scripts/BaseProjectile.gd"

## Ice Lance projectile - Pierces through enemies, hitting multiple targets

# Track enemies we've already hit to avoid double-hitting
var hit_targets: Array = []

func _ready() -> void:
	super._ready()
	_setup_icelance_vfx()

func _setup_icelance_vfx() -> void:
	"""Ice-themed visual effects."""
	# Animate the outer glow with ice shimmer
	if outer_glow:
		var glow_scale_tween = create_tween()
		glow_scale_tween.set_loops()
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.85, 0.12), 0.2)
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.7, 0.10), 0.2)
	
	# Pulsing glow on the core with cyan tint
	if core_glow:
		var core_tween = create_tween()
		core_tween.set_loops()
		core_tween.tween_property(core_glow, "scale", Vector2(0.12, 0.18), 0.25)
		core_tween.tween_property(core_glow, "scale", Vector2(0.09, 0.15), 0.25)
	
	# Color shift for main projectile - ice colors
	if main_bolt:
		var color_tween = create_tween()
		color_tween.set_loops()
		color_tween.tween_property(main_bolt, "modulate", Color(0.5, 0.8, 1.0), 0.35)
		color_tween.tween_property(main_bolt, "modulate", Color(0.3, 0.7, 1.0), 0.35)
	
	# Add trailing ice crystal particles
	particles = GPUParticles2D.new()
	add_child(particles)
	particles.amount = 30
	particles.lifetime = 0.6
	particles.emitting = true
	particles.local_coords = false
	particles.process_material = _create_particle_material()
	particles.z_index = -1
	# Use star particle for ice crystals
	particles.texture = preload("res://Assets/Sprites/Particles/star_01.png")
	# Color the particles cyan/blue for ice
	particles.modulate = Color(0.4, 0.8, 1.0, 0.7)

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material for trailing ice crystals."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Particle behavior - scatter slightly with downward drift
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 120.0
	particle_mat.initial_velocity_min = 20.0
	particle_mat.initial_velocity_max = 80.0
	particle_mat.gravity = Vector3(0, -30, 0)  # Slight downward drift for falling crystals
	
	# Fade and scale over lifetime
	particle_mat.scale_min = 0.2
	particle_mat.scale_max = 0.5
	
	# Enable rotation flags
	particle_mat.particle_flag_disable_z = true
	particle_mat.particle_flag_align_y = false
	particle_mat.particle_flag_rotate_y = false
	
	# Random initial rotation for each particle
	particle_mat.angle_min = 0.0
	particle_mat.angle_max = 360.0
	
	# Slower spinning for ice crystals
	particle_mat.angular_velocity_min = -90.0
	particle_mat.angular_velocity_max = 90.0
	
	return particle_mat

func _on_area_entered(area: Area2D) -> void:
	"""Override: Pierce through enemies instead of stopping."""
	var target = area.get_parent()
	
	# Check if we already hit this target
	if target in hit_targets:
		return
	
	# Mark as hit
	hit_targets.append(target)
	
	# Deal damage and keep moving
	if target.has_method("take_damage"):
		target.take_damage(damage, global_position, "hit_effect", "ice")
	
	# Visual feedback for hit
	_play_damage_flash()
	
	# Don't destroy, keep piercing!
