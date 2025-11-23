extends "res://Scripts/BaseProjectile.gd"

## Thunderbolt projectile - DoT (Damage over Time) that sticks to enemies

# DoT properties
var damage_per_tick: int = 10
var damage_interval: float = 0.15
var is_attached: bool = false
var attached_target = null
var damage_timer: Timer
const TOTAL_TICKS: int = 10  # Always tick this many times when attached
var ticks_remaining: int = TOTAL_TICKS

func _ready() -> void:
	super._ready()
	_setup_damage_timer()
	_setup_thunderbolt_vfx()

func _setup_thunderbolt_vfx() -> void:
	"""Thunderbolt-specific visual effects."""
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
	
	# Pulsing outer glow ring (breathing effect)
	if outer_glow:
		var glow_scale_tween = create_tween().set_loops()
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.85, 0.12), 0.15)
		glow_scale_tween.tween_property(outer_glow, "scale", Vector2(0.7, 0.10), 0.15)
	
	# Pulse the core glow (bright flash effect)
	if core_glow:
		var core_tween = create_tween().set_loops()
		core_tween.tween_property(core_glow, "modulate", Color(1.2, 1.2, 1.2, 1), 0.08)
		core_tween.tween_property(core_glow, "modulate", Color(1.5, 1.5, 1.5, 0.8), 0.1)
		core_tween.tween_property(core_glow, "modulate", Color(1.0, 1.0, 1.0, 1), 0.08)
	
	# Color shift over time (white -> blue -> purple)
	if main_bolt:
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
	particles.local_coords = false
	particles.process_material = _create_particle_material()
	particles.z_index = -1
	particles.texture = preload("res://Assets/Sprites/Particles/spark_01.png")

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material for trailing sparks."""
	var particle_mat = ParticleProcessMaterial.new()
	
	# Particle behavior - scatter in all directions
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3.ZERO
	
	# Fade and scale over lifetime
	particle_mat.scale_min = 0.3
	particle_mat.scale_max = 0.8
	
	# Enable rotation flags
	particle_mat.particle_flag_disable_z = true
	particle_mat.particle_flag_align_y = false
	particle_mat.particle_flag_rotate_y = false
	
	# Random initial rotation for each particle (starting angle)
	particle_mat.angle_min = 0.0
	particle_mat.angle_max = 360.0
	
	# Random spinning motion over time
	particle_mat.angular_velocity_min = -360.0
	particle_mat.angular_velocity_max = 360.0
	
	return particle_mat

func _setup_damage_timer() -> void:
	"""Setup the damage over time timer."""
	damage_timer = Timer.new()
	add_child(damage_timer)
	damage_timer.wait_time = damage_interval
	damage_timer.timeout.connect(_on_damage_tick)

func setup(direction: Vector2, projectile_damage: int = 50) -> void:
	"""Setup projectile with DoT damage calculation."""
	super.setup(direction, projectile_damage)
	# Calculate damage per tick to match total damage over TOTAL_TICKS
	# Remove the max(10, ...) cap so multipliers work correctly
	damage_per_tick = int(float(damage) / float(TOTAL_TICKS))
	# Ensure at least 1 damage per tick (safety check)
	damage_per_tick = max(1, damage_per_tick)

func _physics_process(delta: float) -> void:
	"""Override: Stop movement when attached to target."""
	if not is_attached:
		position += velocity * delta

func _on_area_entered(area: Area2D) -> void:
	"""Handle collision with enemies - attach and start DoT."""
	var target = area.get_parent()
	if target and not is_attached:
		_attach_to_target(target)

func _attach_to_target(target) -> void:
	"""Attach to target and start dealing damage over time."""
	is_attached = true
	attached_target = target
	velocity = Vector2.ZERO
	
	# Stop the lifetime timer
	var lifetime_timer = $Lifetime
	if lifetime_timer:
		lifetime_timer.stop()
	
	# Reset tick counter
	ticks_remaining = TOTAL_TICKS
	
	if particles:
		particles.emitting = false
	
	damage_timer.start()
	
	# Initial damage hit (counts as first tick)
	ticks_remaining -= 1
	_deal_damage_to_target()
	
	_play_attachment_effect()

func _on_damage_tick() -> void:
	"""Called each damage interval to deal DoT damage."""
	if not is_attached or not attached_target or not is_instance_valid(attached_target):
		_destroy()
		return
	
	if ticks_remaining <= 0:
		_destroy()
		return
	
	ticks_remaining -= 1
	_deal_damage_to_target()

func _deal_damage_to_target() -> void:
	"""Apply damage to the attached target."""
	if attached_target.has_method("take_damage"):
		attached_target.take_damage(damage_per_tick, global_position, "hit_effect", "lightning")
	_play_damage_flash()

func _play_attachment_effect() -> void:
	"""Visual effect when attaching to target."""
	if visual:
		var attach_tween = create_tween()
		attach_tween.set_parallel(true)
		attach_tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.1)
		attach_tween.tween_property(visual, "modulate", Color(1.5, 1.5, 2.0), 0.1)
		attach_tween.chain().set_parallel(true)
		attach_tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)
		attach_tween.tween_property(visual, "modulate", Color.WHITE, 0.2)
