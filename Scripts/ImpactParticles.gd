extends Node2D

## Impact particles that fly outward from hit point

@onready var particles: Array[Sprite2D] = []

const PARTICLE_COUNT: int = 5  # Fewer particles for subtlety
const PARTICLE_SPEED: float = 400.0
const PARTICLE_LIFETIME: float = 0.6  # Shorter lifetime
const SPREAD_ANGLE: float = 45.0  # Tighter spread
const GRAVITY_STRENGTH: float = 200.0  # Reduced gravity for more horizontal motion
const GRAVITY_DELAY: float = 0.2  # Delay before gravity kicks in

var particle_textures: Array[Texture2D] = []
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = PARTICLE_LIFETIME

func _ready() -> void:
	# Load elongated particle textures (look more like wood splinters)
	particle_textures = [
		load("res://Assets/Sprites/Particles/scratch_01.png"),
		load("res://Assets/Sprites/Particles/trace_01.png"),
		load("res://Assets/Sprites/Particles/trace_02.png"),
		load("res://Assets/Sprites/Particles/slash_01.png"),
	]

func setup(spawn_direction: Vector2, spawn_color: Color = Color(0.6, 0.4, 0.2)) -> void:
	"""Setup the particle effect with direction and color."""
	direction = spawn_direction.normalized()
	
	# Create particle sprites with correct direction
	for i in range(PARTICLE_COUNT):
		var particle = Sprite2D.new()
		particle.texture = particle_textures[randi() % particle_textures.size()]
		
		# Smaller, thinner scale for subtle splinters (80% smaller)
		var base_scale = randf_range(0.03, 0.07)
		particle.scale = Vector2(base_scale * 0.6, base_scale)  # Make them thinner (splinter-like)
		
		add_child(particle)
		particles.append(particle)
		
		# Random spread within cone
		var angle_offset = randf_range(-SPREAD_ANGLE / 2, SPREAD_ANGLE / 2)
		var particle_dir = direction.rotated(deg_to_rad(angle_offset))
		var speed = randf_range(PARTICLE_SPEED * 0.7, PARTICLE_SPEED * 1.3)
		
		# Orient particle along its direction of travel
		particle.rotation = particle_dir.angle()
		
		# Store velocity and rotation in metadata
		particle.set_meta("velocity", particle_dir * speed)
		particle.set_meta("rotation_speed", randf_range(-3, 3))  # Slower rotation
		particle.set_meta("time_alive", 0.0)  # Track time for gravity delay
		
		# Lighter wood color with more variation
		var color_variation = randf_range(-0.1, 0.1)
		var wood_color = Color(
			spawn_color.r + color_variation,
			spawn_color.g + color_variation,
			spawn_color.b + color_variation,
			0.8  # Slightly transparent
		)
		particle.modulate = wood_color

func _process(delta: float) -> void:
	lifetime -= delta
	
	# Update each particle
	for particle in particles:
		if particle:
			var velocity: Vector2 = particle.get_meta("velocity")
			var rotation_speed: float = particle.get_meta("rotation_speed")
			var time_alive: float = particle.get_meta("time_alive")
			
			# Update time
			time_alive += delta
			particle.set_meta("time_alive", time_alive)
			
			# Apply gravity only after delay (let them fly horizontally first)
			if time_alive > GRAVITY_DELAY:
				velocity.y += GRAVITY_STRENGTH * delta
			
			# Apply velocity
			particle.position += velocity * delta
			particle.rotation += rotation_speed * delta
			
			# Store updated velocity
			particle.set_meta("velocity", velocity)
			
			# Fade out
			var alpha = lifetime / PARTICLE_LIFETIME
			particle.modulate.a = alpha
	
	# Clean up when done
	if lifetime <= 0:
		queue_free()
