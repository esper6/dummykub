extends "res://Scripts/BaseProjectile.gd"

## Ice Nova - AOE damage around the player

# AOE properties
var nova_radius: float = 200.0
var expansion_speed: float = 800.0  # How fast the nova expands
var max_radius: float = 200.0
var hit_targets: Array = []

func _ready() -> void:
	super._ready()
	_setup_icelance_vfx()
	# Start expanding immediately
	_start_nova_expansion()

func _start_nova_expansion() -> void:
	"""Start the nova expansion effect."""
	# Expand collision shape over time
	var expansion_tween = create_tween()
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		var shape = collision_shape.shape as CircleShape2D
		shape.radius = 0.0  # Start at 0
		expansion_tween.tween_method(
			func(radius): shape.radius = radius,
			0.0,
			max_radius,
			max_radius / expansion_speed
		)
	
	# Expand visual effects
	if visual:
		visual.scale = Vector2(0.0, 0.0)  # Start at 0 scale
		var visual_tween = create_tween()
		visual_tween.tween_property(visual, "scale", Vector2(1.0, 1.0), max_radius / expansion_speed)

func _physics_process(_delta: float) -> void:
	"""Override: Don't move - stay at spawn position."""
	# No movement for nova - it stays where it spawns
	pass

func setup(_direction: Vector2, projectile_damage: int = 50) -> void:
	"""Initialize the nova - direction is ignored for AOE."""
	super.setup(Vector2.ZERO, projectile_damage)  # No direction needed
	# Reset visual rotation for circular nova
	if visual:
		visual.rotation = 0.0

func _setup_icelance_vfx() -> void:
	"""Ice-themed visual effects for nova."""
	# Animate the outer glow with ice shimmer (circular pulse)
	if outer_glow:
		var glow_scale_tween = create_tween()
		glow_scale_tween.set_loops()
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(1.2, 1.2), 0.3)
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.9, 0.9), 0.3)
	
	# Pulsing glow on the core with cyan tint
	if core_glow:
		var core_tween = create_tween()
		core_tween.set_loops()
		core_tween.tween_property(core_glow, "scale", Vector2(0.3, 0.3), 0.25)
		core_tween.tween_property(core_glow, "scale", Vector2(0.2, 0.2), 0.25)
	
	# Color shift for main projectile - ice colors
	if main_bolt:
		var color_tween = create_tween()
		color_tween.set_loops()
		color_tween.tween_property(main_bolt, "modulate", Color(0.5, 0.8, 1.0), 0.35)
		color_tween.tween_property(main_bolt, "modulate", Color(0.3, 0.7, 1.0), 0.35)
	
	# Add expanding ice crystal particles (outward nova effect)
	particles = GPUParticles2D.new()
	add_child(particles)
	particles.amount = 60  # More particles for nova
	particles.lifetime = 0.8
	particles.emitting = true
	particles.local_coords = false
	particles.process_material = _create_particle_material()
	particles.z_index = -1
	particles.texture = preload("res://Assets/Sprites/Particles/star_01.png")
	particles.modulate = Color(0.4, 0.8, 1.0, 0.7)

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material for expanding ice nova."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Particle behavior - expand outward in all directions
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 360.0  # Full 360 degrees
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 200.0
	particle_mat.gravity = Vector3(0, 0, 0)  # No gravity for nova
	
	# Fade and scale over lifetime
	particle_mat.scale_min = 0.3
	particle_mat.scale_max = 0.8
	
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
	"""Handle enemies entering the nova area."""
	var target = area.get_parent()
	
	# Check if we already hit this target
	if target in hit_targets:
		return
	
	# Mark as hit
	hit_targets.append(target)
	
	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(damage, global_position, "hit_effect", "ice")
	
	# Visual feedback for hit
	_play_damage_flash()
