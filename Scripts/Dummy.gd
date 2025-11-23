extends Node2D

## Training dummy that reacts to hits

@onready var visual_root: Node2D = $VisualRoot
@onready var hitstop_timer: Timer = $HitstopTimer
@onready var dummy_sprite: AnimatedSprite2D = $Dummy
@onready var health_bar: ProgressBar = $HealthBar

var in_hitstop: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var base_position: Vector2 = Vector2.ZERO

# Health system
const MAX_HEALTH: int = 200
var current_health: int = MAX_HEALTH
var is_dead: bool = false

const HITSTOP_DURATION: float = 0.08
const KNOCKBACK_STRENGTH: float = 30.0
const RETURN_SPEED: float = 8.0

# Damage number scene
const DamageNumber = preload("res://Scenes/DamageNumber.tscn")
const ImpactParticles = preload("res://Scenes/ImpactParticles.tscn")
const ExpOrb = preload("res://Scenes/ExpOrb.tscn")

func _ready() -> void:
	base_position = visual_root.position
	
	# Initialize health bar to match MAX_HEALTH
	if health_bar:
		health_bar.max_value = MAX_HEALTH
		health_bar.value = current_health
	
	# Show dummy and start with idle animation
	if dummy_sprite:
		dummy_sprite.visible = true
		if dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("idle"):
			dummy_sprite.play("idle")
	
	# Notify companions that a dummy has spawned
	EventBus.dummy_spawned.emit(self)

func _process(delta: float) -> void:
	if in_hitstop:
		return
	
	# Apply knockback and return to center
	if knockback_velocity.length() > 0.1:
		visual_root.position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, delta * 5.0)
	
	# Return to base position
	if visual_root.position.distance_to(base_position) > 0.5:
		visual_root.position = visual_root.position.lerp(base_position, delta * RETURN_SPEED)
	else:
		visual_root.position = base_position

func take_damage(damage: int, hit_from_position: Vector2 = Vector2.ZERO, hit_animation: String = "hit_effect", damage_type: String = "physical") -> void:
	# Don't take damage if already dead
	if is_dead:
		return
	
	# Reduce health
	current_health -= damage
	
	# Update health bar
	if health_bar:
		health_bar.value = current_health
	
	# Spawn floating damage number (BEFORE death check so it shows on killing blows)
	_spawn_damage_number(damage)
	
	# Check for death
	if current_health <= 0:
		current_health = 0
		if health_bar:
			health_bar.value = 0
		_die(damage_type)
		return
	
	# Spawn impact particles on opposite side
	_spawn_impact_particles(hit_from_position)
	
	# Play hit effect animation
	play_hit_effect(hit_animation)
	
	# Apply knockback (direction based on hit position)
	var knockback_dir = Vector2.RIGHT if hit_from_position.x < global_position.x else Vector2.LEFT
	knockback_velocity = knockback_dir * KNOCKBACK_STRENGTH
	
	# Visual feedback - shake and scale (base/post)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector2(0.9, 1.1), 0.05)
	tween.tween_property(visual_root, "rotation", 0.1, 0.05)
	tween.chain().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector2.ONE, 0.15)
	tween.tween_property(visual_root, "rotation", 0.0, 0.15)
	
	# Also shake the dummy sprite for impact
	var sprite_tween = create_tween()
	var original_pos = dummy_sprite.position
	for i in range(3):
		sprite_tween.tween_property(dummy_sprite, "position:x", original_pos.x + randf_range(-3, 3), 0.03)
	sprite_tween.tween_property(dummy_sprite, "position", original_pos, 0.05)
	
	# Start hitstop
	_start_hitstop()

func _spawn_damage_number(damage: int) -> void:
	var damage_num = DamageNumber.instantiate()
	get_parent().add_child(damage_num)
	
	# Position above the dummy with some randomness
	var spawn_offset = Vector2(randf_range(-30, 30), randf_range(-100, -50))
	damage_num.global_position = global_position + spawn_offset
	
	# Put damage numbers on top of everything
	damage_num.z_index = 100
	
	# Set color based on damage amount
	var color = Color.WHITE
	if damage >= 30:
		color = Color.ORANGE_RED  # Big hits are red/orange
	elif damage >= 20:
		color = Color.YELLOW  # Medium hits are yellow
	
	damage_num.setup(damage, color)

func _spawn_impact_particles(hit_from_position: Vector2) -> void:
	"""Spawn wood splinter particles on the opposite side of the hit."""
	if hit_from_position == Vector2.ZERO:
		return  # No position provided, skip particles
	
	var impact = ImpactParticles.instantiate()
	get_parent().add_child(impact)
	
	# Calculate direction from hit source to dummy center
	var hit_direction = (global_position - hit_from_position).normalized()
	
	# Spawn particles on the opposite side (exit side)
	var spawn_offset = hit_direction * 60  # 60 pixels behind dummy
	impact.global_position = global_position + spawn_offset
	
	# Particles fly in the hit direction
	impact.setup(hit_direction, Color(0.6, 0.4, 0.2))  # Brown wood color

func _start_hitstop() -> void:
	in_hitstop = true
	hitstop_timer.wait_time = HITSTOP_DURATION
	hitstop_timer.start()

func play_hit_effect(animation_name: String = "hit_effect") -> void:
	"""Play a hit effect animation. Scalable for different attack types."""
	if not dummy_sprite:
		return  # No dummy sprite node, skip
	
	# Check if animation exists
	if not dummy_sprite.sprite_frames:
		return
	
	if not dummy_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Hit effect animation '" + animation_name + "' not found!")
		return
	
	# Play the hit effect
	dummy_sprite.play(animation_name)
	
	# Return to idle when effect finishes
	if not dummy_sprite.animation_finished.is_connected(_on_hit_effect_finished):
		dummy_sprite.animation_finished.connect(_on_hit_effect_finished)

func _on_hit_effect_finished() -> void:
	"""Return to idle animation after hit effect completes."""
	if dummy_sprite and dummy_sprite.sprite_frames:
		# Go back to idle animation
		if dummy_sprite.sprite_frames.has_animation("idle"):
			dummy_sprite.play("idle")

func _on_hitstop_timer_timeout() -> void:
	in_hitstop = false

func _die(damage_type: String) -> void:
	"""Handle dummy death with different animations based on damage type."""
	is_dead = true
	
	# Notify companions that dummy died (so they can immediately find new target)
	EventBus.dummy_died.emit(self)
	
	# Stop all movement/hitstop
	knockback_velocity = Vector2.ZERO
	in_hitstop = false
	
	# Grant EXP to player
	_grant_exp_to_player()
	
	# Play appropriate death animation based on damage type
	match damage_type:
		"physical":
			_play_death_animation_physical()
		"fire":
			_play_death_animation_fire()
		"ice":
			_play_death_animation_ice()
		"lightning":
			_play_death_animation_lightning()
		_:
			# Default to physical if unknown type
			_play_death_animation_physical()

func _grant_exp_to_player() -> void:
	"""Spawn EXP orbs that will fly to the EXP bar and grant EXP."""
	const EXP_REWARD: int = 35
	const ORB_COUNT: int = 3  # Spawn 3 orbs per kill
	
	# Calculate EXP per orb (make sure total adds up)
	var exp_per_orb = EXP_REWARD / ORB_COUNT
	var remainder = EXP_REWARD % ORB_COUNT
	
	# Spawn multiple orbs for visual effect
	for i in range(ORB_COUNT):
		var orb = ExpOrb.instantiate()
		get_parent().add_child(orb)
		
		# Position at dummy location with slight random offset
		var offset = Vector2(randf_range(-20, 20), randf_range(-30, -10))
		orb.global_position = global_position + offset
		
		# Give remainder to last orb to ensure total is correct
		if i == ORB_COUNT - 1:
			orb.exp_amount = exp_per_orb + remainder
		else:
			orb.exp_amount = exp_per_orb
		
		orb.z_index = 10  # Above most things
		
		# Stagger the float start slightly for visual variety
		orb.float_time = i * 0.1

func _play_death_animation_physical() -> void:
	"""Death animation for physical attacks (punch, kick, uppercut)."""
	
	# Check if death animation exists in sprite frames
	if dummy_sprite and dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("death_physical"):
		dummy_sprite.play("death_physical")
	else:
		# Fallback: dramatic fall and fade (apply to BOTH visual_root and dummy_sprite)
		var death_tween = create_tween()
		death_tween.set_parallel(true)
		# Rotate and drop both the base/post and the dummy sprite
		death_tween.tween_property(visual_root, "rotation", -PI/2, 0.5).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_root, "position:y", visual_root.position.y + 100, 0.5).set_ease(Tween.EASE_IN)
		death_tween.tween_property(visual_root, "modulate:a", 0.0, 0.5)
		# Also rotate and fade the dummy sprite
		death_tween.tween_property(dummy_sprite, "rotation", -PI/2, 0.5).set_ease(Tween.EASE_IN)
		death_tween.tween_property(dummy_sprite, "position:y", dummy_sprite.position.y + 100, 0.5).set_ease(Tween.EASE_IN)
		death_tween.tween_property(dummy_sprite, "modulate:a", 0.0, 0.5)
		death_tween.finished.connect(_on_death_animation_finished)

func _play_death_animation_fire() -> void:
	"""Death animation for fire attacks."""
	
	if dummy_sprite and dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("death_fire"):
		dummy_sprite.play("death_fire")
	else:
		# Fallback: Burn up effect - flash red and disintegrate
		var death_tween = create_tween()
		# Flash base/post red
		death_tween.tween_property(visual_root, "modulate", Color.ORANGE_RED, 0.2)
		death_tween.tween_property(visual_root, "modulate", Color.DARK_RED, 0.2)
		death_tween.tween_property(visual_root, "scale", Vector2(1.2, 0.8), 0.3)
		death_tween.tween_property(visual_root, "modulate:a", 0.0, 0.3)
		
		# Also flash dummy sprite with fire colors
		var sprite_tween = create_tween()
		sprite_tween.tween_property(dummy_sprite, "modulate", Color.ORANGE_RED, 0.2)
		sprite_tween.tween_property(dummy_sprite, "modulate", Color.DARK_RED, 0.2)
		sprite_tween.tween_property(dummy_sprite, "scale", Vector2(dummy_sprite.scale.x * 1.2, dummy_sprite.scale.y * 0.8), 0.3)
		sprite_tween.tween_property(dummy_sprite, "modulate:a", 0.0, 0.3)
		
		death_tween.finished.connect(_on_death_animation_finished)

func _play_death_animation_ice() -> void:
	"""Death animation for ice attacks."""
	
	if dummy_sprite and dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("death_ice"):
		dummy_sprite.play("death_ice")
	else:
		# Fallback: Freeze and shatter - turn blue/white then disappear
		var death_tween = create_tween()
		death_tween.tween_property(visual_root, "modulate", Color.CYAN, 0.3)
		death_tween.tween_interval(0.2)
		# Shatter effect - multiple quick scale pulses then fade
		death_tween.tween_property(visual_root, "scale", Vector2(1.1, 1.1), 0.05)
		death_tween.tween_property(visual_root, "scale", Vector2(0.9, 0.9), 0.05)
		death_tween.tween_property(visual_root, "scale", Vector2(1.05, 1.05), 0.05)
		death_tween.tween_property(visual_root, "modulate:a", 0.0, 0.2)
		
		# Also freeze and shatter the dummy sprite
		var sprite_tween = create_tween()
		sprite_tween.tween_property(dummy_sprite, "modulate", Color.CYAN, 0.3)
		sprite_tween.tween_interval(0.2)
		# Shatter effect on sprite
		sprite_tween.tween_property(dummy_sprite, "scale", Vector2(dummy_sprite.scale.x * 1.1, dummy_sprite.scale.y * 1.1), 0.05)
		sprite_tween.tween_property(dummy_sprite, "scale", Vector2(dummy_sprite.scale.x * 0.9, dummy_sprite.scale.y * 0.9), 0.05)
		sprite_tween.tween_property(dummy_sprite, "scale", Vector2(dummy_sprite.scale.x * 1.05, dummy_sprite.scale.y * 1.05), 0.05)
		sprite_tween.tween_property(dummy_sprite, "modulate:a", 0.0, 0.2)
		
		death_tween.finished.connect(_on_death_animation_finished)

func _play_death_animation_lightning() -> void:
	"""Death animation for lightning attacks - dramatic electrocution with buildup."""
	
	if dummy_sprite and dummy_sprite.sprite_frames and dummy_sprite.sprite_frames.has_animation("death_lightning"):
		dummy_sprite.play("death_lightning")
	else:
		# Dramatic lightning death: charge up → violent shake → explode
		var death_tween = create_tween()
		var sprite_tween = create_tween()
		
		# Phase 1: Charge up with increasing intensity (0.4s)
		for i in range(8):
			var intensity = float(i) / 8.0  # 0.0 to 1.0
			var flash_time = 0.05 - (intensity * 0.02)  # Gets faster
			
			# Flash yellow/white with increasing brightness
			var bright_yellow = Color(1.0, 1.0, 0.3 + intensity * 0.4)
			death_tween.tween_property(visual_root, "modulate", bright_yellow, flash_time)
			death_tween.tween_property(visual_root, "modulate", Color.WHITE, flash_time)
			
			sprite_tween.tween_property(dummy_sprite, "modulate", bright_yellow, flash_time)
			sprite_tween.tween_property(dummy_sprite, "modulate", Color.WHITE, flash_time)
			
			# Vibrate with increasing violence
			var shake_amount = 3.0 + (intensity * 7.0)  # 3px to 10px
			death_tween.tween_callback(func(): visual_root.position += Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount)))
			sprite_tween.tween_callback(func(): dummy_sprite.position += Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount)))
		
		# Phase 2: Peak electrocution - freeze white for a moment (0.1s)
		death_tween.tween_property(visual_root, "modulate", Color.WHITE, 0.05)
		sprite_tween.tween_property(dummy_sprite, "modulate", Color.WHITE, 0.05)
		death_tween.tween_interval(0.05)
		sprite_tween.tween_interval(0.05)
		
		# Phase 3: Explosive disintegration - scale up and fade
		death_tween.set_parallel(true)
		death_tween.tween_property(visual_root, "scale", Vector2(1.5, 1.5), 0.2)
		death_tween.tween_property(visual_root, "modulate", Color(1.0, 1.0, 0.5, 0.0), 0.2)  # Yellow fade
		
		sprite_tween.set_parallel(true)
		sprite_tween.tween_property(dummy_sprite, "scale", Vector2(dummy_sprite.scale.x * 1.5, dummy_sprite.scale.y * 1.5), 0.2)
		sprite_tween.tween_property(dummy_sprite, "modulate", Color(1.0, 1.0, 0.5, 0.0), 0.2)  # Yellow fade
		
		death_tween.finished.connect(_on_death_animation_finished)

func _on_death_animation_finished() -> void:
	"""Called when death animation completes."""
	# TODO: Could spawn a new dummy here or trigger game over/next wave
	queue_free()
