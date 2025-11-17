extends CharacterBody2D

## Player wizard with punch-kick-uppercut combo system and platformer movement

signal hit_landed(damage: int)
signal attack_cooldown_started(duration: float)
signal skill_cooldown_started(duration: float)
signal exp_gained(amount: int)
signal level_up(new_level: int)
signal no_cooldown_activated()  # Emitted when No Cooldown buff activates

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
const JUMP_VELOCITY: float = -700.0  # Increased for snappier jump
const DOUBLE_JUMP_VELOCITY: float = -550.0  # Fixed arc, no variable height
const GRAVITY: float = 2200.0  # Increased for faster, snappier feel
const FALL_GRAVITY: float = 2800.0  # Even faster when falling for more responsive feel
const POGO_BOUNCE_VELOCITY: float = -700.0  # Bounce when pogo hits

# Variable jump height (only for first jump, not double jump)
const JUMP_CUT_MULTIPLIER_SHORT: float = 0.3  # Tap jump (level 1)
const JUMP_CUT_MULTIPLIER_MEDIUM: float = 0.55  # Short hold (level 2)
const JUMP_CUT_MULTIPLIER_LONG: float = 0.75  # Medium hold (level 3)
const JUMP_SHORT_THRESHOLD: float = 0.1  # Release before this = shortest jump
const JUMP_MEDIUM_THRESHOLD: float = 0.2  # Release before this = medium jump
const JUMP_LONG_THRESHOLD: float = 0.35  # Release before this = long jump (full = no release)

var facing_right: bool = true
var double_jump_unlocked: bool = false  # Has the player acquired the double jump ability?
var has_double_jump: bool = false  # Can use double jump right now (resets on landing)
var is_first_jump: bool = true  # Track if current jump is first or double
var jump_held_time: float = 0.0  # Track how long jump button is held

# Attack properties
const PUNCH_DAMAGE: int = 10
const KICK_DAMAGE: int = 20
const UPPERCUT_DAMAGE: int = 35
const POGO_DAMAGE: int = 30
const HITSTOP_DURATION: float = 0.08  # Freeze frames duration
const COMBO_WINDOW: float = 0.5  # Time to continue combo
var damage_multiplier: float = 1.0  # Base damage multiplier (modified by power-ups)

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
const Fireball = preload("res://Scenes/Fireball.tscn")
const IceLance = preload("res://Scenes/IceLance.tscn")
var current_skill: String = ""  # No skill at start - must choose at level 2
var skill_unlocked: bool = false  # Has the player unlocked a skill?
var skill_cooldown: float = 0.0
const SKILL_COOLDOWN_TIME: float = 1.0  # 1 second between casts

# EXP and leveling system
var current_level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100  # EXP needed for level 2

# Elemental imbue system
var elemental_imbue_active: bool = false
var elemental_imbue_timer: float = 0.0
var current_melee_element: String = "physical"  # Default to physical damage

# No cooldown buff system
var no_cooldown_active: bool = false
var no_cooldown_timer: float = 0.0

# Attack cooldown system (triggers after 3-hit combo)
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME: float = 0.7  # 2 seconds cooldown after full combo
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
	
	# Update no cooldown timer
	if no_cooldown_active and no_cooldown_timer > 0:
		no_cooldown_timer -= delta
		if no_cooldown_timer <= 0:
			no_cooldown_active = false
			print("No cooldown buff expired")
	
	# Update cooldowns (unless no cooldown is active)
	if not no_cooldown_active:
		if skill_cooldown > 0:
			skill_cooldown -= delta
		
		if attack_cooldown > 0:
			attack_cooldown -= delta
			if attack_cooldown <= 0:
				attack_on_cooldown = false
	else:
		# Clear all cooldowns when no cooldown is active
		skill_cooldown = 0
		attack_cooldown = 0
		attack_on_cooldown = false
	
	# Update elemental imbue timer
	if elemental_imbue_active and elemental_imbue_timer > 0:
		elemental_imbue_timer -= delta
		if elemental_imbue_timer <= 0:
			elemental_imbue_active = false
			current_melee_element = "physical"
			print("Elemental imbue expired")
	
	# Pogo cooldown resets when player starts descending
	if pogo_on_cooldown and velocity.y > 0:  # Falling
		pogo_on_cooldown = false
	
	if not in_hitstop:
		# Apply gravity (reduced during pogo, faster when falling)
		if not is_on_floor():
			if is_pogo_attacking:
				velocity.y += GRAVITY * delta * 0.5  # Slower fall during pogo
			else:
				# Use faster gravity when falling for snappier feel
				var current_gravity = FALL_GRAVITY if velocity.y > 0 else GRAVITY
				velocity.y += current_gravity * delta
		
		# Handle jump (ground jump + double jump)
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				# First jump from ground - variable height
				velocity.y = JUMP_VELOCITY
				is_first_jump = true
				jump_held_time = 0.0
				# Only give double jump if unlocked
				if double_jump_unlocked:
					has_double_jump = true
			elif has_double_jump and double_jump_unlocked:
				# Double jump in air - fixed height
				velocity.y = DOUBLE_JUMP_VELOCITY
				is_first_jump = false
				has_double_jump = false  # Used up the double jump
		
		# Variable jump height (only for first jump)
		if is_first_jump and velocity.y < 0:  # Moving upward
			if Input.is_action_pressed("jump"):
				# Track how long jump is held
				jump_held_time += delta
			else:
				# Jump button released - cut jump based on hold duration
				if jump_held_time < JUMP_SHORT_THRESHOLD:
					# Very short tap - cut to 30%
					velocity.y *= JUMP_CUT_MULTIPLIER_SHORT
					is_first_jump = false  # Stop checking after cut
				elif jump_held_time < JUMP_MEDIUM_THRESHOLD:
					# Short hold - cut to 55%
					velocity.y *= JUMP_CUT_MULTIPLIER_MEDIUM
					is_first_jump = false
				elif jump_held_time < JUMP_LONG_THRESHOLD:
					# Medium hold - cut to 75%
					velocity.y *= JUMP_CUT_MULTIPLIER_LONG
					is_first_jump = false
				# If held longer than LONG threshold, let it go full height
		
		# Reset double jump and first jump flag when landing
		if is_on_floor():
			if not has_double_jump and double_jump_unlocked:
				has_double_jump = true
			is_first_jump = true  # Reset for next jump
		
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
	
	# Reset combo state after animation finishes
	await get_tree().create_timer(0.4).timeout
	_reset_combo()

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
	# Get the enemy that was hit
	var enemy = area.get_parent()
	
	# Check if we haven't hit this enemy yet in this attack
	if enemy in hit_enemies_this_attack:
		return
	
	# Mark as hit
	hit_enemies_this_attack.append(enemy)
	
	# Deal damage directly to the enemy
	if enemy.has_method("take_damage"):
		# Apply player's damage multiplier, plus god mode bonus if active
		var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
		var actual_damage = int(current_attack_damage * damage_multiplier * god_mode_bonus)
		# Use current elemental imbue (or physical if not active)
		enemy.take_damage(actual_damage, global_position, "hit_effect", current_melee_element)
		
		# Emit signal for score tracking with ACTUAL damage dealt
		hit_landed.emit(actual_damage)
	else:
		# Fallback: emit base damage if enemy doesn't have take_damage method
		hit_landed.emit(current_attack_damage)
	
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
	# Check if skill is unlocked
	if not skill_unlocked or current_skill == "":
		return  # No skill unlocked yet
	
	# Check cooldown
	if skill_cooldown > 0:
		return  # Still on cooldown
	
	# Cast based on current skill
	match current_skill:
		"thunderbolt":
			_cast_thunderbolt()
		"fireball":
			_cast_fireball()
		"icelance":
			_cast_icelance()
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
	# Apply player's damage multiplier, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var damage = int(50 * damage_multiplier * god_mode_bonus)
	thunderbolt.setup(direction, damage)
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown (only emit UI signal if not in no cooldown mode)
	skill_cooldown = SKILL_COOLDOWN_TIME
	if not no_cooldown_active:
		skill_cooldown_started.emit(SKILL_COOLDOWN_TIME)

func _cast_fireball() -> void:
	"""Cast a fireball projectile."""
	var fireball = Fireball.instantiate()
	get_parent().add_child(fireball)
	
	# Position at player's location (slightly in front)
	var offset = Vector2(40, -60) if facing_right else Vector2(-40, -60)
	fireball.global_position = global_position + offset
	
	# Set direction (towards mouse or facing direction)
	var direction: Vector2
	if get_viewport():
		var mouse_pos = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_mouse_pos = camera.get_screen_center_position() + (mouse_pos - get_viewport_rect().size / 2)
			direction = (world_mouse_pos - global_position).normalized()
		else:
			direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	else:
		direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	
	# Setup the projectile
	# Apply player's damage multiplier, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var damage = int(50 * damage_multiplier * god_mode_bonus)
	fireball.setup(direction, damage)
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown (only emit UI signal if not in no cooldown mode)
	skill_cooldown = SKILL_COOLDOWN_TIME
	if not no_cooldown_active:
		skill_cooldown_started.emit(SKILL_COOLDOWN_TIME)

func _cast_icelance() -> void:
	"""Cast an ice lance projectile."""
	var icelance = IceLance.instantiate()
	get_parent().add_child(icelance)
	
	# Position at player's location (slightly in front)
	var offset = Vector2(40, -60) if facing_right else Vector2(-40, -60)
	icelance.global_position = global_position + offset
	
	# Set direction (towards mouse or facing direction)
	var direction: Vector2
	if get_viewport():
		var mouse_pos = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_mouse_pos = camera.get_screen_center_position() + (mouse_pos - get_viewport_rect().size / 2)
			direction = (world_mouse_pos - global_position).normalized()
		else:
			direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	else:
		direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	
	# Setup the projectile
	# Apply player's damage multiplier, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var damage = int(50 * damage_multiplier * god_mode_bonus)
	icelance.setup(direction, damage)
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown (only emit UI signal if not in no cooldown mode)
	skill_cooldown = SKILL_COOLDOWN_TIME
	if not no_cooldown_active:
		skill_cooldown_started.emit(SKILL_COOLDOWN_TIME)

func unlock_skill(skill_name: String) -> void:
	"""Unlock a skill for the player."""
	current_skill = skill_name
	skill_unlocked = true
	print("Player unlocked skill: ", skill_name)

func _start_attack_cooldown() -> void:
	"""Start the attack cooldown after full combo."""
	attack_on_cooldown = true
	attack_cooldown = ATTACK_COOLDOWN_TIME
	# Only emit UI signal if not in no cooldown mode
	if not no_cooldown_active:
		attack_cooldown_started.emit(ATTACK_COOLDOWN_TIME)

func grant_double_jump() -> void:
	"""Grant the double jump ability from power-up."""
	double_jump_unlocked = true
	has_double_jump = true  # Also give them one use immediately
	print("Double jump ability granted!")

func add_damage_multiplier(multiplier: float) -> void:
	"""Add a damage multiplier power-up."""
	damage_multiplier *= multiplier
	print("Damage multiplier increased! Now %.1fx damage" % damage_multiplier)
	_play_powerup_effect(Color(1.0, 0.8, 0.2))

func apply_elemental_imbue(duration: float) -> void:
	"""Apply elemental imbue to melee attacks based on chosen skill."""
	elemental_imbue_active = true
	elemental_imbue_timer = duration
	
	# Set element based on current skill
	match current_skill:
		"thunderbolt":
			current_melee_element = "lightning"
		"fireball":
			current_melee_element = "fire"
		"icelance":
			current_melee_element = "ice"
		_:
			current_melee_element = "physical"  # Fallback
	
	print("Elemental imbue activated! Melee attacks now deal %s damage for %.0f seconds" % [current_melee_element, duration])
	_play_powerup_effect(Color(0.8, 0.4, 1.0))

func apply_no_cooldown(duration: float) -> void:
	"""Remove all cooldowns for a duration."""
	no_cooldown_active = true
	no_cooldown_timer = duration
	
	# Immediately clear all cooldowns
	skill_cooldown = 0
	attack_cooldown = 0
	attack_on_cooldown = false
	
	# Notify UI to clear cooldown animations
	no_cooldown_activated.emit()
	
	print("NO COOLDOWN MODE! Spam away for %.0f seconds! 🔥" % duration)
	_play_powerup_effect(Color(0.2, 1.0, 0.6))

func _play_powerup_effect(color: Color) -> void:
	"""Visual feedback for collecting a power-up."""
	var flash_tween = create_tween()
	flash_tween.tween_property(anim_sprite, "modulate", color, 0.1)
	flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.3)

func gain_exp(amount: int) -> void:
	"""Gain experience points and handle leveling up."""
	current_exp += amount
	exp_gained.emit(amount)
	print("Gained ", amount, " EXP! (", current_exp, "/", exp_to_next_level, ")")
	
	# Check for level up
	while current_exp >= exp_to_next_level:
		_level_up()

func _level_up() -> void:
	"""Level up the player."""
	current_exp -= exp_to_next_level
	current_level += 1
	
	# Calculate next level requirement (could scale, but keeping at 100 for now)
	exp_to_next_level = 100
	
	print("LEVEL UP! Now level ", current_level)
	level_up.emit(current_level)
	
	# Visual feedback
	_play_level_up_effect()

func _play_level_up_effect() -> void:
	"""Visual effect for leveling up."""
	# Flash and scale pulse (preserve facing direction!)
	var facing_multiplier = 1.0 if facing_right else -1.0
	var levelup_tween = create_tween()
	levelup_tween.set_parallel(true)
	levelup_tween.tween_property(visual_root, "scale", Vector2(1.3 * facing_multiplier, 1.3), 0.2)
	levelup_tween.tween_property(visual_root, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	
	levelup_tween.chain().set_parallel(true)
	levelup_tween.tween_property(visual_root, "scale", Vector2(1.0 * facing_multiplier, 1.0), 0.3)
	levelup_tween.tween_property(visual_root, "modulate", Color.WHITE, 0.3)

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
