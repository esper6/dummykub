extends CharacterBody2D

## Player wizard with punch-kick-uppercut combo system and platformer movement

signal hit_landed(damage: int)
signal attack_cooldown_started(duration: float)
signal skill_cooldown_started(duration: float)

@onready var visual_root: Node2D = $VisualRoot
@onready var combo_timer: Timer = $ComboTimer
@onready var hitstop_timer: Timer = $HitstopTimer
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_visual: ColorRect = $WeaponHitbox/WeaponVisual
@onready var anim_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

# Combo system
enum ComboState { IDLE, PUNCH, KICK, UPPERCUT, POGO }
var current_combo_state: ComboState = ComboState.IDLE
var combo_count: int = 0
var can_input: bool = true
var in_hitstop: bool = false
var game_active: bool = true
var is_pogo_attacking: bool = false

# Movement properties
const MOVE_SPEED: float = 400.0
const JUMP_VELOCITY: float = -600.0
const GRAVITY: float = 1500.0
const POGO_BOUNCE_VELOCITY: float = -700.0  # Bounce when pogo hits
var facing_right: bool = true

# Attack properties
const PUNCH_DAMAGE: int = 10
const KICK_DAMAGE: int = 20
const UPPERCUT_DAMAGE: int = 35
const POGO_DAMAGE: int = 30
const HITSTOP_DURATION: float = 0.08  # Freeze frames duration
const COMBO_WINDOW: float = 0.5  # Time to continue combo

# Animation offsets
var attack_offset: Vector2 = Vector2.ZERO
var attack_animation_time: float = 0.0

# Attack tracking
var current_attack_damage: int = 0
var hit_enemies_this_attack: Array = []

# Pogo animation tracking
var last_pogo_animation: String = ""
var pogo_animations: Array[String] = ["pogo1", "pogo2", "pogo3"]
var pogo_on_cooldown: bool = false  # Resets when player starts descending

# Skill system
const Thunderbolt = preload("res://Scenes/Thunderbolt.tscn")
var current_skill: String = "thunderbolt"  # Can switch skills later
var skill_cooldown: float = 0.0
const SKILL_COOLDOWN_TIME: float = 1.0  # 1 second between casts

# Attack cooldown system (triggers after 3-hit combo)
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 2.0  # 2 seconds cooldown after full combo
var attack_on_cooldown: bool = false

func _ready() -> void:
	combo_timer.wait_time = COMBO_WINDOW
	weapon_hitbox.monitoring = false
	# Set initial weapon position based on facing direction
	weapon_hitbox.position.x = 70 if facing_right else -70
	# Hide weapon visual (keep hitbox functional)
	weapon_visual.visible = false

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	
	# Update cooldowns
	if skill_cooldown > 0:
		skill_cooldown -= delta
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			attack_on_cooldown = false
	
	# Pogo cooldown resets when player starts descending
	if pogo_on_cooldown and velocity.y > 0:  # Falling
		pogo_on_cooldown = false
	
	if not in_hitstop:
		# Apply gravity (reduced during pogo)
		if not is_on_floor():
			if is_pogo_attacking:
				velocity.y += GRAVITY * delta * 0.5  # Slower fall during pogo
			else:
				velocity.y += GRAVITY * delta
		
		# Handle jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		# Handle horizontal movement (allowed during pogo)
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			velocity.x = direction * MOVE_SPEED
			# Flip character to face movement direction
			if direction > 0 and not facing_right:
				_flip_character(true)
			elif direction < 0 and facing_right:
				_flip_character(false)
		else:
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 5.0)
		
		# Move character
		move_and_slide()
		
		# End pogo if we hit the ground
		if is_on_floor() and is_pogo_attacking:
			_end_pogo()
	
	# Animate sprite based on state
	if not in_hitstop and game_active:
		if is_pogo_attacking:
			# Force pogo animation to keep playing
			if anim_sprite.animation != last_pogo_animation:
				anim_sprite.play(last_pogo_animation)
			# Make sure it's always playing
			if not anim_sprite.is_playing():
				anim_sprite.play(last_pogo_animation)
		elif current_combo_state == ComboState.IDLE:
			# Only play idle/walk when not in any attack state and on the ground
			if is_on_floor():
				if velocity.x != 0:
					if anim_sprite.animation != "walk":
						anim_sprite.play("walk")
				else:
					if anim_sprite.animation != "idle":
						anim_sprite.play("idle")
			# If in air and not attacking, keep previous animation or play idle
			elif not (anim_sprite.animation in pogo_animations):
				if anim_sprite.animation != "idle" and anim_sprite.animation != "walk":
					anim_sprite.play("idle")
	
	# Animate attack offset back to neutral
	if attack_offset != Vector2.ZERO:
		attack_animation_time += delta * 10.0
		attack_offset = attack_offset.lerp(Vector2.ZERO, delta * 15.0)
		visual_root.position = attack_offset

func _flip_character(right: bool) -> void:
	facing_right = right
	visual_root.scale.x = 1.0 if right else -1.0
	# Flip weapon hitbox position
	weapon_hitbox.position.x = 70 if right else -70

func _input(event: InputEvent) -> void:
	if not game_active or in_hitstop:
		return
	
	if event.is_action_pressed("attack") and can_input:
		# Check for pogo attack (down + attack while in air)
		# Pogo is independent of combo cooldown, but has its own physics-based cooldown
		if not is_on_floor() and Input.is_action_pressed("ui_down") and not pogo_on_cooldown:
			_attack_pogo()
		elif not attack_on_cooldown:
			# Normal attacks require cooldown to be finished
			_perform_attack()
	
	# Skill button (right-click)
	if event.is_action_pressed("skill"):
		_cast_skill()

func _perform_attack() -> void:
	can_input = false
	
	# Determine which attack in the combo
	match current_combo_state:
		ComboState.IDLE:
			_attack_punch()
		ComboState.PUNCH:
			_attack_kick()
		ComboState.KICK:
			_attack_uppercut()
		ComboState.UPPERCUT:
			# Combo finished, reset and start over
			_reset_combo()
			_attack_punch()

func _attack_punch() -> void:
	current_combo_state = ComboState.PUNCH
	combo_count = 1
	_do_attack(PUNCH_DAMAGE, Vector2(10, -5), "punch")
	combo_timer.start()

func _attack_kick() -> void:
	current_combo_state = ComboState.KICK
	combo_count = 2
	_do_attack(KICK_DAMAGE, Vector2(15, 0), "kick")
	combo_timer.start()

func _attack_uppercut() -> void:
	current_combo_state = ComboState.UPPERCUT
	combo_count = 3
	_do_attack(UPPERCUT_DAMAGE, Vector2(12, -8), "uppercut")
	
	# Trigger attack cooldown after finishing 3-hit combo
	_start_attack_cooldown()
	# After uppercut, combo resets
	combo_timer.stop()

func _attack_pogo() -> void:
	is_pogo_attacking = true
	current_combo_state = ComboState.POGO
	pogo_on_cooldown = true  # Set cooldown (resets when falling again)
	can_input = false
	
	# Choose random pogo animation (but never the same as last time)
	var chosen_animation = _get_random_pogo_animation()
	anim_sprite.play(chosen_animation)
	
	# Position weapon hitbox downward
	var stored_x = weapon_hitbox.position.x
	weapon_hitbox.position = Vector2(0, 40)  # Below the player
	
	# Store damage for this attack
	current_attack_damage = POGO_DAMAGE
	hit_enemies_this_attack.clear()
	
	# Enable weapon hitbox
	weapon_hitbox.monitoring = true
	# weapon_visual stays hidden
	
	# Store original position to restore later
	await get_tree().create_timer(0.3).timeout
	
	# Only disable hitbox after timer, but keep pogo state active until landing
	if is_pogo_attacking:
		weapon_hitbox.monitoring = false
		weapon_hitbox.position.x = stored_x
		weapon_hitbox.position.y = -80
		# Don't set is_pogo_attacking to false here - let landing handle it
		can_input = true

func _end_pogo() -> void:
	is_pogo_attacking = false
	current_combo_state = ComboState.IDLE
	weapon_hitbox.monitoring = false
	# Restore weapon position
	weapon_hitbox.position.x = 70 if facing_right else -70
	weapon_hitbox.position.y = -80
	can_input = true
	# Let the normal animation system in _physics_process handle the transition
	# Don't force idle/walk here because we might be bouncing in the air

func _do_attack(damage: int, offset: Vector2, animation_name: String) -> void:
	# Play the specific attack animation
	anim_sprite.play(animation_name)
	
	# Visual feedback
	attack_offset = offset
	visual_root.position = offset
	attack_animation_time = 0.0
	
	# Store damage for this attack
	current_attack_damage = damage
	hit_enemies_this_attack.clear()
	
	# Enable weapon hitbox
	weapon_hitbox.monitoring = true
	# weapon_visual stays hidden
	
	# Disable after a short time (attack duration)
	await get_tree().create_timer(0.15).timeout
	weapon_hitbox.monitoring = false
	
	# Re-enable input after attack completes (if not in hitstop from hitting something)
	if not in_hitstop:
		can_input = true

func _start_hitstop() -> void:
	in_hitstop = true
	hitstop_timer.wait_time = HITSTOP_DURATION
	hitstop_timer.start()

func _on_hitstop_timer_timeout() -> void:
	in_hitstop = false
	can_input = true

func _on_combo_timer_timeout() -> void:
	_reset_combo()

func _reset_combo() -> void:
	current_combo_state = ComboState.IDLE
	combo_count = 0

func _on_weapon_hitbox_area_entered(area: Area2D) -> void:
	# Check if we haven't hit this enemy yet in this attack
	if area.get_parent() in hit_enemies_this_attack:
		return
	
	# Mark as hit
	hit_enemies_this_attack.append(area.get_parent())
	
	# Deal damage
	hit_landed.emit(current_attack_damage)
	
	# Tell the enemy to react
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(current_attack_damage)
	
	# Pogo bounce effect!
	if is_pogo_attacking:
		velocity.y = POGO_BOUNCE_VELOCITY  # Bounce upward
		_end_pogo()
	
	# Start hitstop for impact
	_start_hitstop()

func _get_random_pogo_animation() -> String:
	# Get available animations (all except the last one used)
	var available_animations = pogo_animations.duplicate()
	
	# Remove the last animation if we have one
	if last_pogo_animation != "":
		available_animations.erase(last_pogo_animation)
	
	# Pick a random one from the remaining options
	var chosen = available_animations[randi() % available_animations.size()]
	
	# Remember it for next time
	last_pogo_animation = chosen
	
	return chosen

func _cast_skill() -> void:
	"""Cast the current skill. Scalable for multiple skills."""
	# Check cooldown
	if skill_cooldown > 0:
		return  # Still on cooldown
	
	# Cast based on current skill
	match current_skill:
		"thunderbolt":
			_cast_thunderbolt()
		"fireball":
			pass  # TODO: Add fireball later
		"icebolt":
			pass  # TODO: Add ice bolt later
		_:
			push_warning("Unknown skill: " + current_skill)

func _cast_thunderbolt() -> void:
	"""Cast a thunderbolt projectile."""
	# Create projectile
	var thunderbolt = Thunderbolt.instantiate()
	get_parent().add_child(thunderbolt)
	
	# Position at player's location (slightly in front)
	var offset = Vector2(40, -60) if facing_right else Vector2(-40, -60)
	thunderbolt.global_position = global_position + offset
	
	# Set direction (towards mouse or facing direction)
	var direction: Vector2
	if get_viewport():
		var mouse_pos = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_2d()
		if camera:
			# Convert screen space to world space
			var world_mouse_pos = camera.get_screen_center_position() + (mouse_pos - get_viewport_rect().size / 2)
			direction = (world_mouse_pos - global_position).normalized()
		else:
			direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	else:
		direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	
	# Setup the projectile
	thunderbolt.setup(direction, 50)
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown
	skill_cooldown = SKILL_COOLDOWN_TIME
	skill_cooldown_started.emit(SKILL_COOLDOWN_TIME)

func _start_attack_cooldown() -> void:
	"""Start the attack cooldown after full combo."""
	attack_on_cooldown = true
	attack_cooldown = ATTACK_COOLDOWN_TIME
	attack_cooldown_started.emit(ATTACK_COOLDOWN_TIME)

func _screen_shake(intensity: float, duration: float) -> void:
	"""Create a screen shake effect."""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = create_tween()
	
	# Shake with random offsets
	var shake_count = int(duration / 0.02)  # 50 FPS shake
	for i in range(shake_count):
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(camera, "offset", random_offset, 0.02)
	
	# Return to original position
	shake_tween.tween_property(camera, "offset", original_offset, 0.05)

func game_over() -> void:
	game_active = false
	can_input = false
	weapon_hitbox.monitoring = false
	weapon_visual.visible = false
