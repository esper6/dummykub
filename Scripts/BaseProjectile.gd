extends Area2D

## Base projectile class - common functionality for all projectiles

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

func _physics_process(delta: float) -> void:
	"""Basic movement - can be overridden by child classes."""
	position += velocity * delta

func setup(direction: Vector2, projectile_damage: int = 50) -> void:
	"""Initialize the projectile with direction and damage."""
	velocity = direction.normalized() * speed
	damage = projectile_damage
	
	if visual:
		visual.rotation = direction.angle()

func _setup_enhanced_vfx() -> void:
	"""Create visual effects - override in child classes for custom VFX."""
	_setup_additive_materials()
	
	# Animate main sprite if it exists
	if main_bolt and main_bolt.sprite_frames:
		main_bolt.play("default")

func _setup_additive_materials() -> void:
	"""Setup additive blending materials for glowing sprites."""
	if outer_glow:
		var outer_material = CanvasItemMaterial.new()
		outer_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		outer_glow.material = outer_material
	
	if core_glow:
		var core_material = CanvasItemMaterial.new()
		core_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		core_glow.material = core_material
	
	if main_bolt:
		var bolt_material = CanvasItemMaterial.new()
		bolt_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		main_bolt.material = bolt_material

func _create_particle_material() -> ParticleProcessMaterial:
	"""Create particle material - override in child classes for custom particles."""
	var particle_mat = ParticleProcessMaterial.new()
	
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3.ZERO
	
	particle_mat.scale_min = 0.3
	particle_mat.scale_max = 0.8
	
	particle_mat.particle_flag_disable_z = true
	particle_mat.particle_flag_align_y = false
	particle_mat.particle_flag_rotate_y = false
	
	particle_mat.angle_min = 0.0
	particle_mat.angle_max = 360.0
	
	particle_mat.angular_velocity_min = -360.0
	particle_mat.angular_velocity_max = 360.0
	
	return particle_mat

func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with walls/terrain."""
	if body.is_in_group("wall") or body.is_in_group("terrain"):
		_destroy()

func _on_lifetime_timeout() -> void:
	"""Called when lifetime expires."""
	_destroy()

func _destroy() -> void:
	"""Destroy the projectile with effects."""
	queue_free()

func _play_damage_flash() -> void:
	"""Visual feedback for damage dealt."""
	if visual:
		var flash_tween = create_tween()
		flash_tween.tween_property(visual, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.1)

