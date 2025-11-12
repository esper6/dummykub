extends Area2D

## Thunderbolt projectile skill with enhanced VFX

@onready var visual: Node2D = $Visual
@onready var outer_glow: Sprite2D = $Visual/OuterGlow
@onready var core_glow: Sprite2D = $Visual/CoreGlow
@onready var main_bolt: AnimatedSprite2D = $Visual/MainBolt

# Projectile properties
var velocity: Vector2 = Vector2.ZERO
var damage: int = 50
var speed: float = 600.0
var hit_enemies: Array = []

# VFX nodes (created dynamically)
var point_light: PointLight2D
var particles: GPUParticles2D

func _ready() -> void:
	_setup_enhanced_vfx()

func _setup_enhanced_vfx() -> void:
	"""Create amazing visual effects with sprite layers!"""
	
	# Setup additive blending for glowing effect
	_setup_additive_materials()
	
	# Add dynamic lighting for extra glow
	point_light = PointLight2D.new()
	add_child(point_light)
	point_light.texture_scale = 3.0
	point_light.color = Color(0.4, 0.7, 1.0)  # Electric blue
	point_light.energy = 1.5
	point_light.blend_mode = Light2D.BLEND_MODE_ADD
	
	# Flicker the light for electrical effect
	var light_tween = create_tween().set_loops()
	light_tween.tween_property(point_light, "energy", 2.2, 0.05)
	light_tween.tween_property(point_light, "energy", 1.2, 0.08)
	light_tween.tween_property(point_light, "energy", 1.8, 0.06)
	
	# Animate the main bolt (cycles through your lightning frames)
	if main_bolt and main_bolt.sprite_frames:
		main_bolt.play("default")
	
	# Pulsing outer glow ring (breathing effect)
	if outer_glow:
		var glow_scale_tween = create_tween().set_loops()
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(1.7, 1.7), 0.15)
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(1.4, 1.4), 0.15)
		
		# Rotate the outer glow for motion
		var glow_rotation_tween = create_tween().set_loops()
		glow_rotation_tween.tween_property(outer_glow, "rotation", TAU, 1.0)
	
	# Pulse the core glow (bright flash effect)
	if core_glow:
		var core_tween = create_tween().set_loops()
		core_tween.tween_property(core_glow, "modulate", Color(1.2, 1.2, 1.2, 1), 0.08)
		core_tween.tween_property(core_glow, "modulate", Color(1.5, 1.5, 1.5, 0.8), 0.1)
		core_tween.tween_property(core_glow, "modulate", Color(1.0, 1.0, 1.0, 1), 0.08)
	
	# Subtle overall scale pulse
	var scale_tween = create_tween().set_loops()
	scale_tween.tween_property(visual, "scale", Vector2(1.1, 1.1), 0.12)
	scale_tween.tween_property(visual, "scale", Vector2(0.95, 0.95), 0.1)
	
	# Color shift over time (white -> blue -> purple)
	var color_tween = create_tween()
	color_tween.tween_property(main_bolt, "modulate", Color(0.9, 0.95, 1.0), 0.4)
	color_tween.tween_property(main_bolt, "modulate", Color(0.8, 0.85, 1.0), 0.4)
	color_tween.tween_property(main_bolt, "modulate", Color(0.9, 0.75, 1.0), 0.5)
	
	# Add trailing particles
	particles = GPUParticles2D.new()
	add_child(particles)
	particles.amount = 30
	particles.lifetime = 0.4
	particles.emitting = true
	particles.local_coords = false  # Particles stay in world space (not relative to bolt)
	particles.process_material = _create_particle_material()
	particles.z_index = -1
	particles.texture = preload("res://Assets/Sprites/Particles/spark_01.png")

func _setup_additive_materials() -> void:
	"""Setup additive blending materials for glowing sprites."""
	# Create additive material for outer glow
	if outer_glow:
		var outer_material = CanvasItemMaterial.new()
		outer_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		outer_glow.material = outer_material
	
	# Create additive material for core glow
	if core_glow:
		var core_material = CanvasItemMaterial.new()
		core_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		core_glow.material = core_material
	
	# Main bolt can use normal or additive - try both!
	if main_bolt:
		var bolt_material = CanvasItemMaterial.new()
		bolt_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		main_bolt.material = bolt_material

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material for trailing sparks."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Particle behavior - scatter in all directions
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3.ZERO
	
	# Make emission truly omnidirectional
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 15.0
	
	# Enable rotation flags
	particle_mat.particle_flag_disable_z = true  # Keep particles flat in 2D
	particle_mat.particle_flag_align_y = false  # Don't auto-rotate to velocity
	particle_mat.particle_flag_rotate_y = false  # Don't rotate in 3D space
	
	# Random initial rotation for each particle (starting angle)
	particle_mat.angle_min = 0.0
	particle_mat.angle_max = 360.0
	
	# Random spinning motion over time
	particle_mat.angular_velocity_min = -360.0  # Degrees per second
	particle_mat.angular_velocity_max = 360.0
	
	# Appearance
	particle_mat.scale_min = 0.1
	particle_mat.scale_max = 0.7
	particle_mat.scale_curve = _create_scale_curve()
	
	# Fade out over lifetime
	particle_mat.color = Color(0.6, 0.85, 1.0, 1.0)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0.4, 0.7, 1, 0))
	particle_mat.color_ramp = gradient
	
	return particle_mat

func _create_scale_curve() -> Curve:
	"""Particles shrink over their lifetime."""
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))   # Start at full size
	curve.add_point(Vector2(1, 0.3))   # End at 30% size
	return curve

func _physics_process(delta: float) -> void:
	# Move the projectile
	position += velocity * delta

func setup(direction: Vector2, projectile_damage: int = 50) -> void:
	"""Initialize the projectile with direction and damage."""
	velocity = direction.normalized() * speed
	damage = projectile_damage
	
	# Rotate visual to face direction
	visual.rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	# Hit an enemy
	var target = area.get_parent()
	
	# Don't hit the same enemy twice
	if target in hit_enemies:
		return
	
	hit_enemies.append(target)
	
	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(damage, "hit_effect")  # Can specify different hit animations later
	
	# Create impact effect
	_create_impact_effect()
	
	# Destroy projectile after hitting
	_destroy()

func _on_body_entered(_body: Node2D) -> void:
	# Hit a wall or solid object
	_destroy()

func _on_lifetime_timeout() -> void:
	# Projectile expired
	_destroy()

func _create_impact_effect() -> void:
	"""Create a satisfying impact explosion effect."""
	# Screen shake on impact
	_trigger_screen_shake(5.0, 0.15)
	
	# Bright flash
	var flash_tween = create_tween()
	flash_tween.tween_property(point_light, "energy", 4.0, 0.05)
	flash_tween.tween_property(point_light, "energy", 0.0, 0.15)
	
	# Expand and fade the visual
	var impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(visual, "scale", Vector2(2.5, 2.5), 0.2)
	impact_tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	
	# Burst particles outward
	if particles:
		particles.emitting = false
		var burst = GPUParticles2D.new()
		get_parent().add_child(burst)
		burst.global_position = global_position
		burst.amount = 20
		burst.lifetime = 0.3
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.emitting = true
		
		var burst_material = ParticleProcessMaterial.new()
		burst_material.direction = Vector3(0, 0, 0)
		burst_material.spread = 180.0
		burst_material.initial_velocity_min = 200.0
		burst_material.initial_velocity_max = 400.0
		burst_material.gravity = Vector3.ZERO
		burst_material.scale_min = 3.0
		burst_material.scale_max = 6.0
		burst_material.color = Color(0.8, 0.9, 1.0, 1.0)
		
		var burst_gradient = Gradient.new()
		burst_gradient.set_color(0, Color(1, 1, 1, 1))
		burst_gradient.set_color(1, Color(0.4, 0.7, 1, 0))
		burst_material.color_ramp = burst_gradient
		
		burst.process_material = burst_material
		
		# Clean up burst after it's done
		await get_tree().create_timer(0.5).timeout
		burst.queue_free()

func _trigger_screen_shake(intensity: float, duration: float) -> void:
	"""Trigger a screen shake effect."""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = create_tween()
	
	# Rapid shake
	var shake_count = int(duration / 0.02)
	for i in range(shake_count):
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(camera, "offset", random_offset, 0.02)
	
	# Return to original
	shake_tween.tween_property(camera, "offset", original_offset, 0.05)

func _destroy() -> void:
	"""Destroy the projectile with a fade effect."""
	# Quick fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
