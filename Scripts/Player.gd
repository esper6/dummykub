extends CharacterBody2D

## Player wizard with punch-kick-uppercut combo system and platformer movement

signal hit_landed(damage: int)
signal attack_cooldown_started(duration: float)
signal skill_cooldown_started(duration: float)
signal dash_cooldown_started(duration: float)
signal exp_gained(amount: int)
signal level_up(new_level: int)
signal no_cooldown_activated()  # Emitted when No Cooldown buff activates
signal crit_hit(damage: int)  # Emitted when a critical hit occurs
signal powerup_collected(powerup_type: String, is_temporary: bool, duration: float, extra_data: Dictionary)  # Universal power-up signal

@onready var visual_root: Node2D = $VisualRoot
@onready var combo_timer: Timer = $ComboTimer
@onready var hitstop_timer: Timer = $HitstopTimer
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_visual: ColorRect = $WeaponHitbox/WeaponVisual
@onready var anim_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var powerup_display: HBoxContainer = $PowerupDisplay

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
const DOUBLE_JUMP_VELOCITY: float = -750.0  # Fixed arc, no variable height
const GRAVITY: float = 2200.0  # Increased for faster, snappier feel
const FALL_GRAVITY: float = 2800.0  # Even faster when falling for more responsive feel
const POGO_BOUNCE_VELOCITY: float = -1000.0  # Bounce when pogo hits

# Variable jump height (only for first jump, not double jump)
const JUMP_CUT_MULTIPLIER_SHORT: float = 0.3  # Tap jump (level 1)
const JUMP_CUT_MULTIPLIER_MEDIUM: float = 0.55  # Short hold (level 2)
const JUMP_CUT_MULTIPLIER_LONG: float = 0.75  # Medium hold (level 3)
const JUMP_SHORT_THRESHOLD: float = 0.1  # Release before this = shortest jump
const JUMP_MEDIUM_THRESHOLD: float = 0.2  # Release before this = medium jump
const JUMP_LONG_THRESHOLD: float = 0.35  # Release before this = long jump (full = no release)

# Variable gravity based on jump height (shorter = snappier)
const GRAVITY_SHORT: float = 3500.0  # Very snappy for short hops
const GRAVITY_MEDIUM: float = 2800.0  # Medium snappy
const GRAVITY_LONG: float = 2400.0  # Less snappy
const GRAVITY_FULL: float = 2200.0  # Floaty for full hops (base gravity)
const FALL_GRAVITY_SHORT: float = 4000.0  # Fast fall for short hops
const FALL_GRAVITY_MEDIUM: float = 3200.0  # Medium fall
const FALL_GRAVITY_LONG: float = 3000.0  # Less fast fall
const FALL_GRAVITY_FULL: float = 2800.0  # Normal fall for full hops

enum JumpLevel { SHORT, MEDIUM, LONG, FULL }
var current_jump_level: JumpLevel = JumpLevel.FULL  # Track current jump level

var facing_right: bool = true
var double_jump_unlocked: bool = false  # Has the player acquired the double jump ability?
var has_double_jump: bool = false  # Can use double jump right now (resets on landing)
var is_first_jump: bool = true  # Track if current jump is first or double
var jump_held_time: float = 0.0  # Track how long jump button is held

# Dash properties
var dash_unlocked: bool = false  # Has the player acquired the dash ability?
var dash_cooldown: float = 0.0
const DASH_COOLDOWN_TIME: float = 1.0  # 1 second cooldown
const DASH_SPEED: float = 800.0  # Speed of the dash
const DASH_DURATION: float = 0.2  # How long the dash lasts
var is_dashing: bool = false
var dash_time_remaining: float = 0.0

# Platform fall-through
var platform_fall_through_timer: float = 0.0
const PLATFORM_FALL_THROUGH_TIME: float = 0.2  # How long to ignore platforms

# Attack properties
const PUNCH_DAMAGE: int = 10
const KICK_DAMAGE: int = 20
const UPPERCUT_DAMAGE: int = 35
const POGO_DAMAGE: int = 30
const HITSTOP_DURATION: float = 0.08  # Freeze frames duration
const COMBO_WINDOW: float = 0.5  # Time to continue combo
const ATTACK_DELAY: float = 0.2  # Delay between each attack in combo
var damage_multiplier: float = 1.0  # Base damage multiplier (permanent, stacks multiplicatively)
var attack_speed_multiplier: float = 1.0  # Modifies attack delay (higher = faster attacks)
var attack_delay_timer: float = 0.0  # Tracks time since last attack

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

# Skill casting state
var is_casting_skill: bool = false  # Is player currently casting a skill?
var skill_startup_timer: float = 0.0  # Timer for startup frames
var skill_suspension_timer: float = 0.0  # Timer for suspension after cast
const SKILL_STARTUP_TIME: float = 0.2  # Startup frames before skill casts
const SKILL_SUSPENSION_TIME: float = 0.15  # How long to suspend after cast
const SKILL_RECOIL_FORCE: float = 300.0  # Recoil force for projectile skills

# EXP and leveling system
var current_level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100  # EXP needed for level 2

# Level 3+ ability system
var crit_chance: float = 0.0  # Percentage (0.0 to 1.0)
var cooldown_reduction: float = 0.0  # Percentage (0.0 to 1.0)

# Ability level tracking (for breakpoint indicators)
var attack_speed_level: int = 0
var crit_chance_level: int = 0
var cooldown_reduction_level: int = 0

# Movement speed boost system (permanent, no duration)
var movement_speed_multiplier: float = 1.0  # Base speed multiplier
var current_melee_element: String = "physical"  # Default to physical damage (for compatibility)

# Stat system (11 stats, each point = +1 level)
var physical_damage: int = 0
var skill_damage: int = 0
var speed: int = 0
var companion: int = 0
var crit_chance_stat: int = 0  # Separate from ability system crit_chance
var crit_damage: int = 0
var exp_gain: int = 0
var cooldown_reduction_stat: int = 0  # Separate from ability system cooldown_reduction
var attack_range: int = 0
var luck: int = 0
var jump_height: int = 0

# Companion system
const Companion = preload("res://Scenes/Companion.tscn")
var active_companions: Array = []

# Stat multipliers (calculated from stat values)
var physical_damage_multiplier: float = 1.0
var skill_damage_multiplier: float = 1.0
var crit_damage_multiplier: float = 2.0  # Base crit damage is 2x

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
	# Set initial weapon position based on facing direction (will be updated with attack range in _flip_character)
	_flip_character(facing_right)
	# Hide weapon visual (keep hitbox functional)
	weapon_visual.visible = false
	# Initialize companions if player already has companion stat
	if companion > 0:
		call_deferred("_update_companions")

func _physics_process(delta: float) -> void:
	if not game_active:
		return
	
	# Update attack delay timer (separate from attack cooldown)
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
	
	# Update no cooldown timer
	if no_cooldown_active and no_cooldown_timer > 0:
		no_cooldown_timer -= delta
		if no_cooldown_timer <= 0:
			no_cooldown_active = false
	
	# Update cooldowns (unless no cooldown is active)
	if not no_cooldown_active:
		if skill_cooldown > 0:
			skill_cooldown -= delta
		
		if attack_cooldown > 0:
			attack_cooldown -= delta
			if attack_cooldown <= 0:
				attack_on_cooldown = false
		
		if dash_cooldown > 0:
			dash_cooldown -= delta
	else:
		# Clear all cooldowns when no cooldown is active
		skill_cooldown = 0
		attack_cooldown = 0
		attack_on_cooldown = false
		dash_cooldown = 0
	
	# Update skill casting timers
	if is_casting_skill:
		if skill_startup_timer > 0:
			skill_startup_timer -= delta
			if skill_startup_timer <= 0:
				# Startup complete, actually cast the skill
				_execute_skill_cast()
		elif skill_suspension_timer > 0:
			skill_suspension_timer -= delta
			if skill_suspension_timer <= 0:
				# Suspension complete, resume normal movement
				is_casting_skill = false
				can_input = true
	
	# Pogo cooldown resets when player starts descending
	if pogo_on_cooldown and velocity.y > 0:  # Falling
		pogo_on_cooldown = false
	
	# Update dash timer
	if is_dashing:
		dash_time_remaining -= delta
		if dash_time_remaining <= 0:
			is_dashing = false
	
	# Update platform fall-through timer
	if platform_fall_through_timer > 0:
		platform_fall_through_timer -= delta
		if platform_fall_through_timer <= 0:
			# Re-enable platform collision
			set_collision_mask_value(1, true)
	
	if not in_hitstop:
		# Apply gravity (reduced during pogo, variable based on jump level, suspended during skill cast)
		if not is_on_floor():
			if is_casting_skill and skill_startup_timer > 0:
				# Suspend gravity and freeze velocity during startup frames
				velocity.y = 0.0  # Freeze vertical velocity during startup
			elif is_casting_skill:
				# During suspension after cast, allow recoil but no gravity
				# Don't apply gravity, but allow existing velocity (recoil) to persist
				pass  # Skip gravity application
			elif is_pogo_attacking:
				velocity.y += GRAVITY * delta * 0.5  # Slower fall during pogo
			else:
				# Use variable gravity based on jump level (shorter = snappier)
				var current_gravity: float
				var current_fall_gravity: float
				
				match current_jump_level:
					JumpLevel.SHORT:
						current_gravity = GRAVITY_SHORT
						current_fall_gravity = FALL_GRAVITY_SHORT
					JumpLevel.MEDIUM:
						current_gravity = GRAVITY_MEDIUM
						current_fall_gravity = FALL_GRAVITY_MEDIUM
					JumpLevel.LONG:
						current_gravity = GRAVITY_LONG
						current_fall_gravity = FALL_GRAVITY_LONG
					JumpLevel.FULL:
						current_gravity = GRAVITY_FULL
						current_fall_gravity = FALL_GRAVITY_FULL
				
				# Use faster gravity when falling for snappier feel
				var applied_gravity = current_fall_gravity if velocity.y > 0 else current_gravity
				velocity.y += applied_gravity * delta
		
		# Handle fall-through platforms (down + jump on platform)
		if Input.is_action_just_pressed("jump") and Input.is_action_pressed("ui_down") and is_on_floor():
			# Check if we're standing on a one-way platform by checking what we collided with
			# Use get_last_slide_collision to see what we're standing on
			var can_fall_through = false
			
			# Check the floor collision
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				
				
				# TileMapLayer = platforms (can fall through)
				if collider is TileMapLayer:
					can_fall_through = true
					break
				# StaticBody2D = solid ground (cannot fall through)
				elif collider is StaticBody2D:
					can_fall_through = false
					break
			
			if can_fall_through:
				platform_fall_through_timer = PLATFORM_FALL_THROUGH_TIME
				set_collision_mask_value(1, false)  # Disable collision with platforms temporarily
				position.y += 2  # Move down slightly to start falling
		
		# Handle jump (ground jump + double jump)
		elif Input.is_action_just_pressed("jump"):
			# Apply jump height stat multiplier (+5% per point)
			var jump_multiplier = 1.0 + (jump_height * 0.05)
			if is_on_floor():
				# First jump from ground - variable height
				velocity.y = JUMP_VELOCITY * jump_multiplier
				is_first_jump = true
				jump_held_time = 0.0
				current_jump_level = JumpLevel.FULL  # Default to full, will be set when cut
				# Only give double jump if unlocked
				if double_jump_unlocked:
					has_double_jump = true
			elif has_double_jump and double_jump_unlocked:
				# Double jump in air - fixed height (use medium gravity for double jump)
				velocity.y = DOUBLE_JUMP_VELOCITY * jump_multiplier
				is_first_jump = false
				current_jump_level = JumpLevel.MEDIUM  # Double jump uses medium gravity
				has_double_jump = false  # Used up the double jump
		
		# Variable jump height (only for first jump)
		if is_first_jump and velocity.y < 0:  # Moving upward
			if Input.is_action_pressed("jump"):
				# Track how long jump is held
				jump_held_time += delta
			else:
				# Jump button released - cut jump based on hold duration
				if jump_held_time < JUMP_SHORT_THRESHOLD:
					# Very short tap - cut to 30% and use snappy gravity
					velocity.y *= JUMP_CUT_MULTIPLIER_SHORT
					current_jump_level = JumpLevel.SHORT
					is_first_jump = false  # Stop checking after cut
				elif jump_held_time < JUMP_MEDIUM_THRESHOLD:
					# Short hold - cut to 55% and use medium gravity
					velocity.y *= JUMP_CUT_MULTIPLIER_MEDIUM
					current_jump_level = JumpLevel.MEDIUM
					is_first_jump = false
				elif jump_held_time < JUMP_LONG_THRESHOLD:
					# Medium hold - cut to 75% and use long gravity
					velocity.y *= JUMP_CUT_MULTIPLIER_LONG
					current_jump_level = JumpLevel.LONG
					is_first_jump = false
				# If held longer than LONG threshold, let it go full height (floaty)
		
		# Reset double jump and first jump flag when landing
		if is_on_floor():
			if not has_double_jump and double_jump_unlocked:
				has_double_jump = true
			is_first_jump = true  # Reset for next jump
			current_jump_level = JumpLevel.FULL  # Reset jump level
		
		# Handle dash input
		if Input.is_action_just_pressed("dash") and dash_unlocked and dash_cooldown <= 0 and not is_dashing:
			_perform_dash()
		
		# Handle horizontal movement (allowed during pogo, overridden by dash, suspended during skill cast)
		if is_casting_skill and skill_startup_timer > 0:
			# Suspend horizontal movement during startup frames
			velocity.x = 0.0
		elif is_casting_skill:
			# During suspension after cast, allow recoil but prevent input-based movement
			# Let velocity decay naturally (recoil will fade)
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 5.0)
		elif is_dashing:
			# During dash, maintain dash velocity (scales with movement speed multiplier)
			var dash_direction = 1.0 if facing_right else -1.0
			var current_dash_speed = DASH_SPEED * movement_speed_multiplier
			velocity.x = dash_direction * current_dash_speed
		else:
			var direction = Input.get_axis("move_left", "move_right")
			# Apply speed stat multiplier (+5% per point)
			var speed_multiplier = 1.0 + (speed * 0.05)
			# Always check and update facing direction based on input, even if velocity is still non-zero
			# This ensures proper flipping after unpausing (e.g., after level up screen)
			if direction > 0 and not facing_right:
				_flip_character(true)
			elif direction < 0 and facing_right:
				_flip_character(false)
			
			if direction != 0:
				var current_speed = MOVE_SPEED * movement_speed_multiplier * speed_multiplier
				velocity.x = direction * current_speed
			else:
				var current_speed = MOVE_SPEED * movement_speed_multiplier * speed_multiplier
				velocity.x = move_toward(velocity.x, 0, current_speed * delta * 5.0)
		
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
	# Flip weapon hitbox position (apply attack range multiplier)
	var range_multiplier = 1.0 + (attack_range * 0.05)
	var base_offset = 70.0 * range_multiplier
	weapon_hitbox.position.x = base_offset if right else -base_offset

func _input(event: InputEvent) -> void:
	if not game_active or in_hitstop:
		return
	
	# Prevent input during skill casting
	if is_casting_skill:
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
	# Check if attack delay is still active
	if attack_delay_timer > 0:
		return
	
	can_input = false
	
	# Set attack delay for next attack (scaled by attack speed multiplier)
	var actual_delay = ATTACK_DELAY / attack_speed_multiplier
	attack_delay_timer = actual_delay
	
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
		# Apply player's damage multiplier, physical damage stat, plus god mode bonus if active
		var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
		var actual_damage = int(current_attack_damage * damage_multiplier * physical_damage_multiplier * god_mode_bonus)
		
		# Roll for critical hit (uses crit_damage_multiplier)
		var is_crit = _roll_crit()
		if is_crit:
			actual_damage = int(actual_damage * crit_damage_multiplier)
			crit_hit.emit(actual_damage)
		
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
	"""Start casting the current skill with startup frames. Scalable for multiple skills."""
	# Check if skill is unlocked
	if not skill_unlocked or current_skill == "":
		return  # No skill unlocked yet
	
	# Check cooldown
	if skill_cooldown > 0:
		return  # Still on cooldown
	
	# Check if already casting
	if is_casting_skill:
		return
	
	# Start casting process with startup frames
	is_casting_skill = true
	can_input = false
	skill_startup_timer = SKILL_STARTUP_TIME
	skill_suspension_timer = 0.0  # Will be set after skill is cast
	

func _execute_skill_cast() -> void:
	"""Actually execute the skill cast after startup frames."""
	# Start suspension timer after skill is cast
	skill_suspension_timer = SKILL_SUSPENSION_TIME
	
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
			is_casting_skill = false
			can_input = true

func _cast_thunderbolt() -> void:
	"""Cast a thunderbolt projectile."""
	# Create projectile
	var thunderbolt = Thunderbolt.instantiate()
	get_parent().add_child(thunderbolt)
	
	# Position at player's location (slightly in front, at body center)
	var offset = Vector2(40, 0) if facing_right else Vector2(-40, 0)
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
	# Apply player's damage multiplier, skill damage stat, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var base_damage = 100  # Base 100 total = 10 per tick over 10 ticks
	# Ensure multiplier is at least 1.0 (safety check)
	var actual_multiplier = max(1.0, damage_multiplier) * skill_damage_multiplier
	var damage = int(base_damage * actual_multiplier * god_mode_bonus)
	thunderbolt.setup(direction, damage)
	
	# Apply recoil (opposite direction of projectile)
	var recoil_direction = -direction
	velocity += recoil_direction * SKILL_RECOIL_FORCE
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown with reduction applied (only emit UI signal if not in no cooldown mode)
	# Combine ability system cooldown_reduction with stat cooldown_reduction_stat (+2% per point)
	var total_cd_reduction = cooldown_reduction + (cooldown_reduction_stat * 0.02)
	total_cd_reduction = clamp(total_cd_reduction, 0.0, 0.8)  # Cap at 80%
	var actual_cooldown = SKILL_COOLDOWN_TIME * (1.0 - total_cd_reduction)
	skill_cooldown = actual_cooldown
	if not no_cooldown_active:
		skill_cooldown_started.emit(actual_cooldown)

func _cast_fireball() -> void:
	"""Cast a fireball projectile."""
	var fireball = Fireball.instantiate()
	get_parent().add_child(fireball)
	
	# Position at player's location (slightly in front, at body center)
	var offset = Vector2(40, 0) if facing_right else Vector2(-40, 0)
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
	# Apply player's damage multiplier, skill damage stat, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var damage = int(50 * damage_multiplier * skill_damage_multiplier * god_mode_bonus)
	fireball.setup(direction, damage)
	
	# Apply recoil (opposite direction of projectile)
	var recoil_direction = -direction
	velocity += recoil_direction * SKILL_RECOIL_FORCE
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown with reduction applied (only emit UI signal if not in no cooldown mode)
	# Combine ability system cooldown_reduction with stat cooldown_reduction_stat (+2% per point)
	var total_cd_reduction = cooldown_reduction + (cooldown_reduction_stat * 0.02)
	total_cd_reduction = clamp(total_cd_reduction, 0.0, 0.8)  # Cap at 80%
	var actual_cooldown = SKILL_COOLDOWN_TIME * (1.0 - total_cd_reduction)
	skill_cooldown = actual_cooldown
	if not no_cooldown_active:
		skill_cooldown_started.emit(actual_cooldown)

func _cast_icelance() -> void:
	"""Cast an ice nova AOE around the player."""
	var icelance = IceLance.instantiate()
	get_parent().add_child(icelance)
	
	# Position at player's center (no offset for nova)
	icelance.global_position = global_position
	
	# Setup the nova (direction doesn't matter for AOE)
	# Apply player's damage multiplier, skill damage stat, plus god mode bonus if active
	var god_mode_bonus = 100.0 if DebugSettings.god_mode else 1.0
	var damage = int(50 * damage_multiplier * skill_damage_multiplier * god_mode_bonus)
	icelance.setup(Vector2.ZERO, damage)  # No direction needed
	
	# No recoil for AOE nova (stays centered on player)
	
	# Add screen shake for casting
	_screen_shake(3.0, 0.1)
	
	# Start cooldown with reduction applied (only emit UI signal if not in no cooldown mode)
	# Combine ability system cooldown_reduction with stat cooldown_reduction_stat (+2% per point)
	var total_cd_reduction = cooldown_reduction + (cooldown_reduction_stat * 0.02)
	total_cd_reduction = clamp(total_cd_reduction, 0.0, 0.8)  # Cap at 80%
	var actual_cooldown = SKILL_COOLDOWN_TIME * (1.0 - total_cd_reduction)
	skill_cooldown = actual_cooldown
	if not no_cooldown_active:
		skill_cooldown_started.emit(actual_cooldown)

func unlock_skill(skill_name: String) -> void:
	"""Unlock a skill for the player."""
	current_skill = skill_name
	skill_unlocked = true

func _start_attack_cooldown() -> void:
	"""Start the attack cooldown after full combo."""
	attack_on_cooldown = true
	# Apply cooldown reduction (combine ability system with stat)
	var total_cd_reduction = cooldown_reduction + (cooldown_reduction_stat * 0.02)
	total_cd_reduction = clamp(total_cd_reduction, 0.0, 0.8)  # Cap at 80%
	var actual_cooldown = ATTACK_COOLDOWN_TIME * (1.0 - total_cd_reduction)
	attack_cooldown = actual_cooldown
	# Only emit UI signal if not in no cooldown mode
	if not no_cooldown_active:
		attack_cooldown_started.emit(actual_cooldown)

func grant_double_jump() -> void:
	"""Grant the double jump ability from relic."""
	double_jump_unlocked = true
	has_double_jump = true  # Also give them one use immediately
	powerup_collected.emit("double_jump", false, 0.0, {})

func grant_dash() -> void:
	"""Grant the dash ability from relic."""
	dash_unlocked = true
	powerup_collected.emit("dash", false, 0.0, {})

func _perform_dash() -> void:
	"""Execute a dash in the direction the player is facing."""
	is_dashing = true
	dash_time_remaining = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN_TIME
	
	# Emit cooldown signal for UI
	dash_cooldown_started.emit(DASH_COOLDOWN_TIME)
	
	# Visual feedback - quick flash
	var dash_tween = create_tween()
	dash_tween.tween_property(anim_sprite, "modulate", Color(0.4, 1.0, 0.6, 1.0), 0.05)
	dash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	

func add_damage_multiplier(multiplier: float, duration: float) -> void:
	"""Add a permanent damage multiplier power-up. Stacks multiplicatively."""
	# Always stack multiplicatively (multiply existing multiplier)
	var is_stacking = damage_multiplier > 1.0
	if is_stacking:
		damage_multiplier *= multiplier
	else:
		damage_multiplier = multiplier
	
	_play_powerup_effect(Color(1.0, 0.8, 0.2))
	powerup_collected.emit("damage_multiplier", false, 0.0, {"multiplier": damage_multiplier, "is_stack": is_stacking})

func apply_movement_speed_boost(multiplier: float, duration: float) -> void:
	"""Apply permanent movement speed boost. Stacks multiplicatively."""
	var is_stacking = movement_speed_multiplier > 1.0
	
	if is_stacking:
		# Multiply the multipliers together (multiplicative stacking)
		movement_speed_multiplier *= multiplier
	else:
		# First activation
		movement_speed_multiplier = multiplier
	
	_play_powerup_effect(Color(0.3, 0.8, 1.0))
	powerup_collected.emit("movement_speed", false, 0.0, {"multiplier": movement_speed_multiplier, "is_stack": is_stacking})

func apply_no_cooldown(duration: float) -> void:
	"""Remove all cooldowns for a duration. Stacks by adding duration."""
	var is_stacking = no_cooldown_active and no_cooldown_timer > 0
	if is_stacking:
		# Add to existing duration
		no_cooldown_timer += duration
	else:
		# First activation
		no_cooldown_active = true
		no_cooldown_timer = duration
		# Immediately clear all cooldowns
		skill_cooldown = 0
		attack_cooldown = 0
		attack_on_cooldown = false
		# Notify UI to clear cooldown animations
		no_cooldown_activated.emit()
	
	_play_powerup_effect(Color(0.2, 1.0, 0.6))
	powerup_collected.emit("no_cooldown", true, no_cooldown_timer, {"is_stack": is_stacking})

func _play_powerup_effect(color: Color) -> void:
	"""Visual feedback for collecting a power-up."""
	var flash_tween = create_tween()
	flash_tween.tween_property(anim_sprite, "modulate", color, 0.1)
	flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.3)

# === Level 3+ Ability Methods ===

func increase_attack_speed(multiplier: float) -> void:
	"""Increase attack speed by a multiplier (1.5 = 50% faster)."""
	attack_speed_multiplier *= multiplier
	attack_speed_level += 1
	_play_powerup_effect(Color(1.0, 0.5, 0.2))

func add_crit_chance(amount: float) -> void:
	"""Add critical hit chance (0.0 to 1.0)."""
	crit_chance += amount
	crit_chance = clamp(crit_chance, 0.0, 1.0)  # Cap at 100%
	crit_chance_level += 1
	_play_powerup_effect(Color(1.0, 0.9, 0.2))

func add_cooldown_reduction(amount: float) -> void:
	"""Add cooldown reduction (0.0 to 1.0)."""
	cooldown_reduction += amount
	cooldown_reduction = clamp(cooldown_reduction, 0.0, 0.8)  # Cap at 80% reduction
	cooldown_reduction_level += 1
	var actual_skill_cd = SKILL_COOLDOWN_TIME * (1.0 - cooldown_reduction)
	var actual_attack_cd = ATTACK_COOLDOWN_TIME * (1.0 - cooldown_reduction)
	_play_powerup_effect(Color(0.3, 0.8, 1.0))

func get_ability_level(ability_id: String) -> int:
	"""Get the current level of an ability."""
	match ability_id:
		"attack_speed":
			return attack_speed_level
		"crit_chance":
			return crit_chance_level
		"cooldown_reduction":
			return cooldown_reduction_level
		_:
			return 0

func _roll_crit() -> bool:
	"""Roll for critical hit. Returns true if crit."""
	# Combine ability system crit_chance with stat crit_chance_stat
	var total_crit_chance = crit_chance + (crit_chance_stat * 0.02)  # +2% per stat point
	total_crit_chance = clamp(total_crit_chance, 0.0, 1.0)  # Cap at 100%
	return randf() < total_crit_chance

func gain_exp(amount: int) -> void:
	"""Gain experience points and handle leveling up."""
	# Apply exp gain multiplier from stat
	var exp_multiplier = 1.0 + (exp_gain * 0.1)  # +10% per point
	var actual_amount = int(amount * exp_multiplier)
	current_exp += actual_amount
	exp_gained.emit(actual_amount)
	
	# Check for level up
	while current_exp >= exp_to_next_level:
		_level_up()

func _level_up() -> void:
	"""Level up the player."""
	current_exp -= exp_to_next_level
	current_level += 1
	
	# Calculate next level requirement (could scale, but keeping at 100 for now)
	exp_to_next_level = 100
	
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
	
	# Clean up companions
	for companion_instance in active_companions:
		if is_instance_valid(companion_instance):
			companion_instance.queue_free()
	active_companions.clear()

# === Stat System Methods ===

func increase_stat(stat_id: String, amount: int) -> void:
	"""Increase a stat by the given amount and apply its effects. Stats are capped at 10."""
	const MAX_STAT_LEVEL = 10
	
	match stat_id:
		"physical_damage":
			physical_damage = min(physical_damage + amount, MAX_STAT_LEVEL)
			_apply_physical_damage_stat()
		"skill_damage":
			skill_damage = min(skill_damage + amount, MAX_STAT_LEVEL)
			_apply_skill_damage_stat()
		"speed":
			speed = min(speed + amount, MAX_STAT_LEVEL)
			# Speed is applied in _physics_process, no need to recalculate here
		"companion":
			companion = min(companion + amount, MAX_STAT_LEVEL)
			_update_companions()
		"crit_chance":
			crit_chance_stat = min(crit_chance_stat + amount, MAX_STAT_LEVEL)
			# Crit chance is calculated in _roll_crit()
		"crit_damage":
			crit_damage = min(crit_damage + amount, MAX_STAT_LEVEL)
			_apply_crit_damage_stat()
		"exp_gain":
			exp_gain = min(exp_gain + amount, MAX_STAT_LEVEL)
			# EXP gain is applied in gain_exp()
		"cooldown_reduction":
			cooldown_reduction_stat = min(cooldown_reduction_stat + amount, MAX_STAT_LEVEL)
			# Cooldown reduction is applied in cooldown calculations
		"attack_range":
			attack_range = min(attack_range + amount, MAX_STAT_LEVEL)
			_apply_attack_range_stat()
		"luck":
			luck = min(luck + amount, MAX_STAT_LEVEL)
			# Luck is used in GameManager for power-up spawning
		"jump_height":
			jump_height = min(jump_height + amount, MAX_STAT_LEVEL)
			# Jump height is applied in jump calculations
		_:
			push_warning("Unknown stat: " + stat_id)
	

func get_stat_value(stat_id: String) -> int:
	"""Get the current value of a stat."""
	match stat_id:
		"physical_damage":
			return physical_damage
		"skill_damage":
			return skill_damage
		"speed":
			return speed
		"companion":
			return companion
		"crit_chance":
			return crit_chance_stat
		"crit_damage":
			return crit_damage
		"exp_gain":
			return exp_gain
		"cooldown_reduction":
			return cooldown_reduction_stat
		"attack_range":
			return attack_range
		"luck":
			return luck
		"jump_height":
			return jump_height
		_:
			push_warning("Unknown stat: " + stat_id)
			return 0

func _apply_physical_damage_stat() -> void:
	"""Apply physical damage stat to multiplier."""
	# +10% per point
	physical_damage_multiplier = 1.0 + (physical_damage * 0.1)

func _apply_skill_damage_stat() -> void:
	"""Apply skill damage stat to multiplier."""
	# +10% per point
	skill_damage_multiplier = 1.0 + (skill_damage * 0.1)

func _apply_crit_damage_stat() -> void:
	"""Apply crit damage stat to multiplier."""
	# Base is 2.0x, +0.2x per point
	crit_damage_multiplier = 2.0 + (crit_damage * 0.2)

func _apply_attack_range_stat() -> void:
	"""Apply attack range stat to weapon hitbox size."""
	# +5% per point to hitbox size
	var range_multiplier = 1.0 + (attack_range * 0.05)
	# Update hitbox position (will be applied when facing changes via _flip_character)
	# Note: This is a simplified approach - you might want to scale the collision shape instead

func _update_companions() -> void:
	"""Update companion count based on companion stat."""
	var target_count = companion
	
	# Remove excess companions
	while active_companions.size() > target_count:
		var companion_instance = active_companions.pop_back()
		if is_instance_valid(companion_instance):
			companion_instance.queue_free()
	
	# Spawn new companions if needed
	while active_companions.size() < target_count:
		_spawn_companion()

func _spawn_companion() -> void:
	"""Spawn a new companion."""
	var companion_instance = Companion.instantiate()
	get_parent().add_child(companion_instance)
	
	# Position near player with some offset
	var spawn_offset = Vector2(randf_range(-50, 50), randf_range(-30, 30))
	companion_instance.global_position = global_position + spawn_offset
	companion_instance.z_index = 1  # Same z_index as player
	
	# Set player reference
	companion_instance.player = self
	
	# Track companion
	active_companions.append(companion_instance)
	
	# Spawn animation
	companion_instance.modulate.a = 0.0
	companion_instance.scale = Vector2(0.5, 0.5)
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(companion_instance, "modulate:a", 1.0, 0.5)
	spawn_tween.tween_property(companion_instance, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT)
	
