extends Node2D

## EXP orb that spawns on dummy kill, floats, then flies to player with tracking

var exp_amount: int = 35
var target_position: Vector2 = Vector2.ZERO
var float_duration: float = 1.0
var fly_duration: float = 0.5
var float_amplitude: float = 20.0  # How much it bobs up and down

var float_time: float = 0.0
var fly_start_position: Vector2 = Vector2.ZERO
var fly_progress: float = 0.0
var state: String = "floating"  # "floating" or "flying"
var start_position: Vector2 = Vector2.ZERO  # Starting position for floating animation

var ball_circle: Polygon2D = null
var glow_circle: Polygon2D = null

func _ready() -> void:
	# Store starting position for floating animation (use global position converted to local)
	# Wait a frame to ensure global_position is set by parent
	await get_tree().process_frame
	start_position = position  # This is now the local position relative to parent
	
	# Set z-index to be visible above most things
	z_index = 50
	
	# Make it a green ball (simple circle)
	_setup_sprite()
	
	# Start floating animation
	float_time = 0.0
	state = "floating"
	
	# Get the player position to track
	_setup_target_position()
	
	print("EXP orb spawned at global_position=", global_position, " local_position=", position, " with exp_amount=", exp_amount)

func _setup_sprite() -> void:
	"""Setup the green ball sprite."""
	# Remove any existing sprite from scene
	var existing_sprite = get_node_or_null("Sprite2D")
	if existing_sprite:
		existing_sprite.queue_free()
	
	# Create a circle using Polygon2D
	ball_circle = Polygon2D.new()
	ball_circle.name = "Ball"
	
	# Create circle points (16 points for smooth circle) - make it bigger
	var radius = 12.0  # Increased from 8.0
	var points = PackedVector2Array()
	for i in range(16):
		var angle = (i / 16.0) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	
	ball_circle.polygon = points
	ball_circle.color = Color(0.2, 1.0, 0.3, 1.0)  # Bright green
	ball_circle.z_index = 1
	ball_circle.visible = true
	
	# Add a glow effect by creating an outer circle
	glow_circle = Polygon2D.new()
	glow_circle.name = "Glow"
	var outer_points = PackedVector2Array()
	var outer_radius = 18.0  # Increased from 12.0
	for i in range(16):
		var angle = (i / 16.0) * TAU
		outer_points.append(Vector2(cos(angle) * outer_radius, sin(angle) * outer_radius))
	glow_circle.polygon = outer_points
	glow_circle.color = Color(0.2, 1.0, 0.3, 0.5)  # More visible glow
	glow_circle.z_index = 0  # Behind the main circle
	glow_circle.visible = true
	
	# Also create a simple Sprite2D with generated circle texture as backup
	var sprite = Sprite2D.new()
	sprite.name = "BackupSprite"
	sprite.texture = _create_circle_texture(24, Color(0.2, 1.0, 0.3, 1.0))
	sprite.z_index = 2
	sprite.position = Vector2.ZERO
	add_child(sprite)
	
	add_child(glow_circle)
	add_child(ball_circle)

func _setup_target_position() -> void:
	"""Find the player position to track."""
	_update_player_target()

func _update_player_target() -> void:
	"""Update target position to player's current position."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try getting by name
		player = get_tree().get_first_node_in_group("Player")
	
	if player:
		target_position = player.global_position
	else:
		# Fallback: use a default position if player not found
		target_position = Vector2(600, 800)  # Approximate player start position

func _process(delta: float) -> void:
	# If start_position is still zero and we have a valid position, update it
	if start_position == Vector2.ZERO and global_position != Vector2.ZERO:
		start_position = position
	
	if state == "floating":
		# Float up and down for 1 second
		float_time += delta
		
		# Bob up and down using sine wave (relative to start position)
		var bob_offset = sin(float_time * 4.0) * float_amplitude
		position.y = start_position.y + bob_offset
		
		# Also add slight horizontal drift
		var drift = sin(float_time * 2.0) * 10.0
		position.x = start_position.x + drift
		
		if float_time >= float_duration:
			# Start flying to player
			state = "flying"
			fly_start_position = global_position
			fly_progress = 0.0
			
	elif state == "flying":
		# Update target to player's current position (tracking)
		_update_player_target()
		
		# Check if we're close enough to the player
		var distance_to_player = global_position.distance_to(target_position)
		if distance_to_player < 30.0:  # Close enough to collect
			# Reached player - grant EXP and remove
			_grant_exp()
			queue_free()
			return
		
		# Fly towards player with tracking
		# Calculate direction to player
		var direction = (target_position - global_position).normalized()
		var speed = 400.0  # Base speed
		
		# Move towards player (smooth tracking)
		var move_distance = speed * delta
		global_position += direction * move_distance
		
		# Scale down as it gets closer
		var distance_factor = clamp(distance_to_player / 200.0, 0.3, 1.0)  # Scale based on distance
		if ball_circle:
			ball_circle.scale = Vector2(distance_factor, distance_factor)
		if glow_circle:
			glow_circle.scale = Vector2(distance_factor * 1.5, distance_factor * 1.5)
		
		# Also fade out as it gets closer
		var alpha = clamp(distance_to_player / 150.0, 0.3, 1.0)  # Fade based on distance
		if ball_circle:
			ball_circle.modulate.a = alpha
		if glow_circle:
			glow_circle.modulate.a = alpha * 0.4

func _create_circle_texture(size: int, color: Color) -> ImageTexture:
	"""Create a simple circle texture."""
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0 - 2
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _grant_exp() -> void:
	"""Grant EXP to the player when orb reaches player."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try getting by name
		player = get_tree().get_first_node_in_group("Player")
	
	if player and player.has_method("gain_exp"):
		player.gain_exp(exp_amount)
		print("EXP orb granted ", exp_amount, " EXP to player")
