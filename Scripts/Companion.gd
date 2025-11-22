extends CharacterBody2D

## Companion dog that follows the player and attacks nearest dummies
## ULTRA-AGGRESSIVE ATTACK MODE: Will attack any dummy in range as soon as possible

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D

# Movement properties (base values, modified by player stats)
const JUMP_VELOCITY: float = -600.0
const GRAVITY: float = 2200.0
const FALL_GRAVITY: float = 2800.0

# AI properties
const ATTACK_RANGE: float = 150.0  # Distance to attack dummy (increased to prevent stuck at 130 pixels)
const DETECTION_RANGE: float = 1000.0  # How far to look for dummies
const ATTACK_COOLDOWN: float = 0.5  # Minimum time between attacks on SAME target
const BASE_ATTACK_DAMAGE: int = 15  # Base damage before multipliers
const BASE_MOVE_SPEED: float = 300.0  # Base movement speed before multipliers
const FORCE_ATTACK_TIMEOUT: float = 0.15  # ULTRA SHORT - force attack if target held this long
const DESPERATION_TIMEOUT: float = 1.0  # If we haven't attacked ANYTHING in this long, force attack
const STUCK_DISTANCE_THRESHOLD: float = 5.0  # If distance changes less than this, we're stuck
const STUCK_TIMEOUT: float = 0.5  # If stuck for this long, force attack

var current_target: Node2D = null
var last_attacked_target: Node2D = null  # Track WHICH target we last attacked
var time_since_last_attack: float = 999.0  # Time since we attacked ANY target
var time_since_attacked_current_target: float = 999.0  # Time since we attacked THIS SPECIFIC target
var time_with_current_target: float = 0.0  # How long we've been targeting current dummy
var facing_right: bool = true
var last_log_time: float = 0.0  # For throttling movement logs

# Stuck detection
var last_distance_to_target: float = 999.0
var time_stuck: float = 0.0  # How long we've been at same distance

# Reference to player for following behavior
var player: Node2D = null

func _ready() -> void:
	# Set z_index to match player (same layer)
	z_index = 1
	
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# Create simple dog sprite if not already set
	if not sprite.texture:
		_create_dog_sprite()
	
	# Listen for dummy spawn/death events for instant reaction
	EventBus.dummy_spawned.connect(_on_dummy_spawned)
	EventBus.dummy_died.connect(_on_dummy_died)
	
	print("🐕 Companion ready! Waiting for targets...")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		var applied_gravity = FALL_GRAVITY if velocity.y > 0 else GRAVITY
		velocity.y += applied_gravity * delta
	
	# Update timers
	time_since_last_attack += delta
	time_since_attacked_current_target += delta
	last_log_time += delta
	if current_target != null:
		time_with_current_target += delta
	
	# CONSTANTLY validate and update target - this prevents stale state
	_validate_and_update_target()
	
	# Decide what to do based on whether we have a valid target
	if current_target != null and is_instance_valid(current_target):
		# We have a target - pursue and attack it
		_pursue_and_attack(delta)
	else:
		# No target - wander around
		_wander(delta)
	
	# Move and update visuals
	move_and_slide()
	_update_facing()

func _validate_and_update_target() -> void:
	"""
	CONSTANTLY check and update our target state.
	This runs every frame to prevent stale state.
	"""
	# Step 1: Validate current target is still alive
	if current_target != null:
		if not is_instance_valid(current_target):
			print("❌ Target invalid, clearing")
			current_target = null
		else:
			var is_dead = current_target.get("is_dead")
			if is_dead != null and is_dead:
				print("💀 Target died, clearing")
				current_target = null
	
	# Step 2: Find the nearest living dummy
	var nearest = _find_nearest_living_dummy()
	
	# Step 3: If nearest is different from current, switch to it
	if nearest != current_target:
		current_target = nearest
		
		if current_target != null:
			var dist = global_position.distance_to(current_target.global_position)
			print("🎯 TARGET SWITCH | New: ", current_target, " | Distance: %.1f" % dist)
			
			# CRITICAL: Reset per-target cooldown when switching targets
			# This allows IMMEDIATE attack on new targets!
			time_with_current_target = 0.0
			time_since_attacked_current_target = 999.0  # Never attacked this target before
			time_stuck = 0.0  # Reset stuck timer for new target
			last_distance_to_target = 999.0
			
			# If we're already in range of new target, we can attack immediately
			if dist <= ATTACK_RANGE:
				print("   ↳ Already in range! Can attack IMMEDIATELY (new target)")
		else:
			print("❌ No valid targets available")
			time_with_current_target = 0.0
			time_since_attacked_current_target = 999.0
			time_stuck = 0.0

func _find_nearest_living_dummy() -> Node2D:
	"""Returns the nearest living dummy within detection range, or null if none found."""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return null
	
	var active_dummies = game_manager.active_dummies
	if active_dummies.is_empty():
		return null
	
	var nearest: Node2D = null
	var nearest_distance: float = DETECTION_RANGE
	
	for dummy in active_dummies:
		# Skip if invalid
		if not is_instance_valid(dummy):
			continue
		
		# Skip if dead
		var is_dead = dummy.get("is_dead")
		if is_dead != null and is_dead:
			continue
		
		# Check distance
		var dist = global_position.distance_to(dummy.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest = dummy
	
	return nearest

func _pursue_and_attack(delta: float) -> void:
	"""Move toward current target and attack when in range."""
	# Validate target exists and is valid
	if current_target == null:
		return
	
	if not is_instance_valid(current_target):
		print("⚠️ Target became invalid during pursuit")
		current_target = null
		return
	
	# Check if target is dead
	var is_dead = current_target.get("is_dead")
	if is_dead != null and is_dead:
		print("⚠️ Target died during pursuit")
		current_target = null
		return
	
	var distance = global_position.distance_to(current_target.global_position)
	
	# Update stuck detection
	var distance_change = abs(distance - last_distance_to_target)
	if distance_change < STUCK_DISTANCE_THRESHOLD:
		time_stuck += delta
	else:
		time_stuck = 0.0
	last_distance_to_target = distance
	
	# ULTRA-AGGRESSIVE ATTACK LOGIC:
	# Attack if ANY of these conditions are true:
	# 1. Never attacked this specific target before (instant attack on target switch)
	# 2. Per-target cooldown is ready (attacked this target before, but cooldown passed)
	# 3. We've had this target for >0.15s without attacking (force attack)
	# 4. We haven't attacked ANYTHING in >1.0s (desperation attack)
	# 5. We're VERY close (<50 pixels) - emergency melee attack (NO COOLDOWN)
	# 6. We're STUCK at same distance for >0.5s - force attack even if out of range!
	
	var is_new_target = (current_target != last_attacked_target)
	var can_attack_this_target = time_since_attacked_current_target >= ATTACK_COOLDOWN
	var force_attack = time_with_current_target >= FORCE_ATTACK_TIMEOUT
	var desperation_attack = time_since_last_attack >= DESPERATION_TIMEOUT
	var emergency_melee = distance <= 50.0  # NO cooldown requirement for emergency melee!
	var stuck_attack = time_stuck >= STUCK_TIMEOUT and distance <= ATTACK_RANGE * 1.5  # Stuck and reasonably close
	
	# Check if we're in normal attack range OR stuck close enough
	var in_attack_range = distance <= ATTACK_RANGE or (stuck_attack and distance <= ATTACK_RANGE * 1.5)
	
	if in_attack_range:
		# We're in range (or stuck close enough)!
		if is_new_target or can_attack_this_target or force_attack or desperation_attack or emergency_melee or stuck_attack:
			# Determine attack type for logging
			var attack_reason = "normal"
			if stuck_attack:
				attack_reason = "STUCK ATTACK (%.1f pixels, stuck %.2fs - FORCING!)" % [distance, time_stuck]
			elif is_new_target:
				attack_reason = "NEW TARGET (instant attack!)"
			elif emergency_melee:
				attack_reason = "EMERGENCY MELEE (%.1f pixels - NO cooldown!)" % distance
			elif desperation_attack:
				attack_reason = "DESPERATION (%.2fs since last attack)" % time_since_last_attack
			elif force_attack:
				attack_reason = "FORCE (target held %.2fs)" % time_with_current_target
			
			if attack_reason != "normal":
				print("🚨 %s ATTACK TRIGGERED!" % attack_reason)
			
			# Final validation before attack
			if current_target != null and is_instance_valid(current_target):
				_perform_attack()
			else:
				print("⚠️ Target became invalid right before attack")
				current_target = null
		else:
			# On cooldown - but log if this persists
			var cooldown_remaining = ATTACK_COOLDOWN - time_since_attacked_current_target
			if time_with_current_target > 0.2:  # Only warn if we've had target for a bit
				print("⏱️ In range (%.1f) waiting | Target cooldown: %.2fs | Time with target: %.2fs" % [distance, cooldown_remaining, time_with_current_target])
			
			# CRITICAL WARNING if we've been stuck here too long (should be impossible now)
			if time_with_current_target > 0.2:  # Much shorter threshold now
				print("🔴 CRITICAL: Been in range for %.2fs without attacking! This should NEVER happen!" % time_with_current_target)
				print("   Debug: is_new=%s, can_attack=%s, force=%s, desperation=%s, emergency=%s, stuck=%s" % [is_new_target, can_attack_this_target, force_attack, desperation_attack, emergency_melee, stuck_attack])
				print("   Timers: since_any_attack=%.2f, since_attacked_this=%.2f, with_target=%.2f, time_stuck=%.2f" % [time_since_last_attack, time_since_attacked_current_target, time_with_current_target, time_stuck])
				print("   Distance: current=%.1f, last=%.1f, change=%.1f" % [distance, last_distance_to_target, distance_change])
				print("   Targets: current=%s, last_attacked=%s" % [current_target, last_attacked_target])
		
		# Slow down when in attack range
		var slow_speed = _get_move_speed()
		velocity.x = move_toward(velocity.x, 0, slow_speed * delta * 5.0)
		return
	
	# Not in range yet - move toward target
	# Only log movement occasionally (every 1 second) to avoid spam
	if last_log_time >= 1.0:
		var stuck_status = " | STUCK %.2fs!" % time_stuck if time_stuck > 0.3 else ""
		print("🏃 Moving to target | Distance: %.1f | Time since attack: %.2fs%s" % [distance, time_since_last_attack, stuck_status])
		last_log_time = 0.0
	
	var direction = (current_target.global_position - global_position).normalized()
	var chase_speed = _get_move_speed()
	velocity.x = direction.x * chase_speed
	
	# Jump over obstacles
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Jump to reach elevated targets
	if current_target.global_position.y < global_position.y - 50 and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _perform_attack() -> void:
	"""Execute an attack on the current target. ALWAYS SUCCEEDS if called."""
	# First null check - before ANY method calls
	if current_target == null:
		print("⚠️ Attack failed: target is null")
		return
	
	# Validity check
	if not is_instance_valid(current_target):
		print("⚠️ Attack failed: target not valid")
		current_target = null
		return
	
	# Check if dummy has take_damage method
	if not current_target.has_method("take_damage"):
		print("⚠️ Attack failed: no take_damage method")
		current_target = null
		return
	
	# Final alive check
	var is_dead = current_target.get("is_dead")
	if is_dead != null and is_dead:
		print("⚠️ Attack failed: target already dead")
		current_target = null
		return
	
	# ATTACK! (Re-validate one more time before the actual attack)
	if current_target == null or not is_instance_valid(current_target):
		print("⚠️ Attack failed: target became invalid during checks")
		return
	
	# Calculate damage with player multipliers
	var base_damage = BASE_ATTACK_DAMAGE
	var damage_multiplier = _get_damage_multiplier()
	var actual_damage = int(base_damage * damage_multiplier)
	
	# Roll for critical hit
	var is_crit = _roll_for_crit()
	if is_crit:
		var crit_mult = _get_crit_damage_multiplier()
		actual_damage = int(actual_damage * crit_mult)
	
	var distance = global_position.distance_to(current_target.global_position)
	current_target.take_damage(actual_damage, global_position, "hit_effect", "physical")
	
	var target_health = current_target.get("current_health") if current_target else "?"
	var was_new = (current_target != last_attacked_target)
	var crit_text = " 💥CRIT!💥" if is_crit else ""
	print("⚔️⚔️⚔️ ATTACKED! | Damage: ", actual_damage, crit_text, " | Distance: %.1f" % distance, " | HP: ", target_health, " | New: ", was_new)
	
	# Update timers
	time_since_last_attack = 0.0  # Reset global attack timer
	time_since_attacked_current_target = 0.0  # Reset per-target timer
	time_with_current_target = 0.0  # Reset time with target
	time_stuck = 0.0  # Reset stuck timer after successful attack
	last_attacked_target = current_target  # Remember which target we just attacked
	
	# Visual feedback
	var flash_tween = create_tween()
	flash_tween.tween_property(visual_root, "modulate", Color(1.5, 1.0, 0.8), 0.1)
	flash_tween.tween_property(visual_root, "modulate", Color.WHITE, 0.2)

func _wander(delta: float) -> void:
	"""Wander around when no target is available."""
	var move_speed = _get_move_speed()
	
	# Always have some baseline movement when wandering
	if is_on_floor():
		# If we're nearly stopped, pick a random direction
		if abs(velocity.x) < 10.0:
			if randf() < 0.1:  # 10% chance per frame when stopped
				velocity.x = randf_range(-move_speed * 0.6, move_speed * 0.6)
				print("🚶 Wandering ", "left" if velocity.x < 0 else "right")
		else:
			# Already moving, occasionally change direction
			if randf() < 0.01:  # 1% chance per frame
				velocity.x = randf_range(-move_speed * 0.6, move_speed * 0.6)
		
		# Gradually slow down
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 1.5)
		
		# Occasional jump
		if randf() < 0.005:  # 0.5% chance per frame
			velocity.y = JUMP_VELOCITY * 0.7
	else:
		# In air, slow down horizontally
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 2.0)

func _on_dummy_spawned(dummy: Node2D) -> void:
	"""Called when a new dummy spawns - immediately check if we should target it."""
	print("📢 Dummy spawned signal received!")
	# Validation will happen next frame automatically, but force a check now
	_validate_and_update_target()
	
	# If we just got this new dummy as target, we can attack immediately
	if current_target == dummy:
		var dist = global_position.distance_to(dummy.global_position)
		print("   ↳ New dummy targeted! Distance: %.1f | Can attack: %s" % [dist, dist <= ATTACK_RANGE])

func _on_dummy_died(dummy: Node2D) -> void:
	"""Called when a dummy dies - immediately find new target."""
	print("📢 Dummy died signal received!")
	
	# If this was our target, clear it
	if current_target == dummy:
		print("   ↳ Was our target, clearing and finding new one...")
		current_target = null
		time_with_current_target = 0.0
		# Immediately find new target - per-target timer will reset when we switch
		_validate_and_update_target()
	
	# If this was the last target we attacked, clear that reference
	if last_attacked_target == dummy:
		last_attacked_target = null

func _update_facing() -> void:
	"""Update sprite facing direction based on velocity."""
	if velocity.x > 0.1:
		facing_right = true
		visual_root.scale.x = 1.0
	elif velocity.x < -0.1:
		facing_right = false
		visual_root.scale.x = -1.0

# ============================================
# PLAYER STAT INTEGRATION
# ============================================

func _get_move_speed() -> float:
	"""Get movement speed with player's movement speed multiplier applied."""
	if not player or not is_instance_valid(player):
		return BASE_MOVE_SPEED
	
	var speed_mult = player.get("movement_speed_multiplier")
	if speed_mult == null:
		return BASE_MOVE_SPEED
	
	return BASE_MOVE_SPEED * speed_mult

func _get_damage_multiplier() -> float:
	"""Get combined damage multiplier from player stats."""
	if not player or not is_instance_valid(player):
		return 1.0
	
	var damage_mult = player.get("damage_multiplier")
	var physical_mult = player.get("physical_damage_multiplier")
	
	var total_mult = 1.0
	if damage_mult != null:
		total_mult *= damage_mult
	if physical_mult != null:
		total_mult *= physical_mult
	
	return total_mult

func _roll_for_crit() -> bool:
	"""Roll for critical hit using player's crit chance."""
	if not player or not is_instance_valid(player):
		return false
	
	var crit_chance = player.get("crit_chance")
	var crit_chance_stat = player.get("crit_chance_stat")
	
	var total_crit_chance = 0.0
	if crit_chance != null:
		total_crit_chance += crit_chance
	if crit_chance_stat != null:
		total_crit_chance += crit_chance_stat * 0.02  # +2% per stat point
	
	total_crit_chance = clamp(total_crit_chance, 0.0, 1.0)
	return randf() < total_crit_chance

func _get_crit_damage_multiplier() -> float:
	"""Get critical damage multiplier from player stats."""
	if not player or not is_instance_valid(player):
		return 2.0  # Default crit is 2x
	
	var crit_mult = player.get("crit_damage_multiplier")
	if crit_mult != null:
		return crit_mult
	
	return 2.0  # Default fallback

# ============================================
# VISUAL CREATION
# ============================================

func _create_dog_sprite() -> void:
	"""Create a simple colored rectangle as a placeholder dog sprite."""
	var dog_body = ColorRect.new()
	dog_body.custom_minimum_size = Vector2(40, 30)
	dog_body.color = Color(0.6, 0.4, 0.2)  # Brown dog color
	dog_body.position = Vector2(-20, -15)
	visual_root.add_child(dog_body)
	
	var dog_head = ColorRect.new()
	dog_head.custom_minimum_size = Vector2(20, 20)
	dog_head.color = Color(0.5, 0.3, 0.1)  # Darker brown
	dog_head.position = Vector2(-10, -25)
	visual_root.add_child(dog_head)
	
	var ear1 = ColorRect.new()
	ear1.custom_minimum_size = Vector2(8, 12)
	ear1.color = Color(0.4, 0.2, 0.1)
	ear1.position = Vector2(-8, -30)
	visual_root.add_child(ear1)
	
	var ear2 = ColorRect.new()
	ear2.custom_minimum_size = Vector2(8, 12)
	ear2.color = Color(0.4, 0.2, 0.1)
	ear2.position = Vector2(4, -30)
	visual_root.add_child(ear2)
	
	var tail = ColorRect.new()
	tail.custom_minimum_size = Vector2(6, 20)
	tail.color = Color(0.6, 0.4, 0.2)
	tail.position = Vector2(20, -10)
	visual_root.add_child(tail)
