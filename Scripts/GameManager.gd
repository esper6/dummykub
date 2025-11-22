extends Node2D

## Main game manager for Dummykub
## Manages the timer, score, and game state

@onready var player = $Player
@onready var dummy = $Dummy
@onready var ui_manager = $UIManager
@onready var pause_menu = $PauseMenu
@onready var timer_label: Label = $UI/TimerLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var damage_label: Label = $UI/DamageLabel
@onready var go_label: Label = $UI/GoLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var score_label: Label = $UI/GameOverPanel/VBoxContainer/ScoreLabel
@onready var hits_label: Label = $UI/GameOverPanel/VBoxContainer/HitsLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var exp_bar: ProgressBar = $UI/ExpBar
@onready var exp_label: Label = $UI/ExpBar/ExpLabel
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var ability_up_screen: CanvasLayer = $AbilityUpScreen
@onready var relic_screen: CanvasLayer = $RelicScreen

const GAME_DURATION: float = 60.0
const POWERUP_SPAWN_INTERVAL: float = 5.0  # Spawn power-up every 5 seconds
const DUMMY_SPAWN_INTERVAL: float = 10.0  # Spawn dummy every 10 seconds
const MAX_DUMMIES: int = 10  # Maximum dummies at once (increased to allow all spawn locations)

# Power-ups (Double Jump removed - now a relic)
const DamageMultiplierPowerup = preload("res://Scenes/DamageMultiplierPowerup.tscn")
const MovementSpeedPowerup = preload("res://Scenes/MovementSpeedPowerup.tscn")
const NoCooldownPowerup = preload("res://Scenes/NoCooldownPowerup.tscn")
const Dummy = preload("res://Scenes/Dummy.tscn")

# Power-up pool for random spawning (double jump removed, now a relic)
var powerup_pool: Array = []

var time_remaining: float = GAME_DURATION
var total_damage: int = 0
var total_hits: int = 0
var game_active: bool = false  # Start inactive until GO! animation finishes

# Dummy spawning system
var active_dummies: Array = []
var time_since_last_dummy_spawn: float = 0.0
@export var dummy_spawn_locations: Array[Vector2] = [
	Vector2(600, 800),   # Left side
	Vector2(900, 700),   # Center upper
	Vector2(1500, 750),  # Far right
	Vector2(400, 750),   # Far left
	Vector2(1200, 800),  # Original position (right side)
]

# Power-up spawning system
var time_since_last_powerup_spawn: float = 0.0
var powerup_spawn_locations: Array = [
	Vector2(500, 800),   # Left ground
	Vector2(800, 800),   # Mid-left ground
	Vector2(1100, 800),  # Mid-right ground
	Vector2(1400, 800),  # Right ground
	Vector2(960, 800),   # Center ground
	Vector2(700, 700),   # Left mid-platform
	Vector2(1200, 700),  # Right mid-platform
]

func _ready() -> void:
	# Add to group for easy finding
	add_to_group("game_manager")
	
	# Connect UI Manager to player cooldowns
	if ui_manager and player:
		ui_manager.setup_player_connections(player)
	
	# Connect to player signals
	if player:
		player.hit_landed.connect(_on_player_hit_landed)
		player.exp_gained.connect(_on_player_exp_gained)
		player.level_up.connect(_on_player_level_up)
	
	# Connect level up screen signal
	if level_up_screen:
		level_up_screen.skill_chosen.connect(_on_skill_chosen)
	
	# Connect ability up screen signal (for level 3+)
	if ability_up_screen:
		ability_up_screen.ability_chosen.connect(_on_ability_chosen)
	
	# Connect relic screen signal (for end of level)
	if relic_screen:
		relic_screen.relic_chosen.connect(_on_relic_chosen)
	
	# Track the initial dummy
	if dummy:
		active_dummies.append(dummy)
		dummy.tree_exited.connect(_on_dummy_died.bind(dummy))
		print("Initial dummy tracked. Active dummies: ", active_dummies.size())
	
	# Spawn dummies at all valid spawn locations at the start
	_spawn_initial_dummies()
	
	# Initialize EXP display
	_update_exp_display()
	
	game_over_panel.hide()
	
	# Show GO! animation before starting
	_show_go_animation()

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# Update timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_end_game()
	
	timer_label.text = "%.1f" % time_remaining
	
	# Update spawn timers
	time_since_last_dummy_spawn += delta
	time_since_last_powerup_spawn += delta
	
	# Check if we should spawn a new dummy
	if should_spawn_dummy():
		_spawn_new_dummy()
	
	# Check if we should spawn a new power-up
	if time_since_last_powerup_spawn >= POWERUP_SPAWN_INTERVAL:
		_spawn_random_powerup()
		time_since_last_powerup_spawn = 0.0

func _on_player_hit_landed(damage: int) -> void:
	total_damage += damage
	total_hits += 1
	
	# Update UI
	combo_label.text = str(total_hits) + " HITS"
	damage_label.text = "Total: " + str(total_damage)

func _end_game() -> void:
	game_active = false
	
	# Emit game ended signal
	EventBus.game_ended.emit(total_damage, total_hits)
	
	# Stop player
	if player:
		player.game_over()
	
	# Show game over panel with stats
	score_label.text = "Total Damage: " + str(total_damage)
	hits_label.text = "Total Hits: " + str(total_hits)
	game_over_panel.show()

func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _show_go_animation() -> void:
	"""Show 'GO!' flash at the start of the round."""
	# Show the label
	go_label.visible = true
	go_label.modulate.a = 0.0
	go_label.scale = Vector2(0.5, 0.5)
	
	# Animate: fade in + scale up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(go_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(go_label, "scale", Vector2(1.2, 1.2), 0.2)
	
	# Hold for a moment
	tween.chain().tween_interval(0.3)
	
	# Animate: fade out + scale up more
	tween.set_parallel(true)
	tween.tween_property(go_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(go_label, "scale", Vector2(1.5, 1.5), 0.3)
	
	# Start the game after animation
	tween.chain().tween_callback(_start_game)

func _start_game() -> void:
	"""Start the actual game after GO! animation."""
	go_label.visible = false
	game_active = true
	# Enable pausing
	if pause_menu:
		pause_menu.enable_pausing()

func _spawn_random_powerup() -> void:
	"""Spawn a random power-up at a random location."""
	# Initialize power-up pool (equal weight for all, double jump removed - now a relic)
	if powerup_pool.is_empty():
		powerup_pool = [
			DamageMultiplierPowerup,
			MovementSpeedPowerup,
			NoCooldownPowerup
		]
	
	# If no power-ups available, don't spawn
	if powerup_pool.is_empty():
		print("No power-ups available to spawn")
		return
	
	# Pick a random power-up from pool
	var random_powerup_scene = powerup_pool[randi() % powerup_pool.size()]
	var powerup = random_powerup_scene.instantiate()
	add_child(powerup)
	
	# Use random spawn location from the pool
	var spawn_pos = powerup_spawn_locations[randi() % powerup_spawn_locations.size()]
	
	powerup.global_position = spawn_pos
	powerup.z_index = 10  # Above most things but below UI
	
	print("Power-up spawned: ", powerup.name, " at ", spawn_pos)
	
	# Spawn animation
	powerup.modulate.a = 0.0
	powerup.scale = Vector2(0.3, 0.3)
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(powerup, "modulate:a", 1.0, 0.4)
	spawn_tween.tween_property(powerup, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT)

func _on_player_exp_gained(_amount: int) -> void:
	"""Called when player gains EXP."""
	_update_exp_display()

func _on_player_level_up(new_level: int) -> void:
	"""Called when player levels up."""
	print("GameManager: Player leveled up to ", new_level)
	_update_exp_display()
	
	# Show level up screen at level 2 for skill selection
	if new_level == 2 and level_up_screen:
		level_up_screen.show_level_up()
	
	# Show ability screen at level 3 for ability selection
	elif new_level == 3 and ability_up_screen:
		ability_up_screen.show_ability_selection()
	
	# Show relic screen at level 4 for relic selection
	elif new_level == 4 and relic_screen:
		relic_screen.show_relic_selection()

func _on_skill_chosen(skill_name: String) -> void:
	"""Called when player chooses a skill from level up screen."""
	print("GameManager: Player chose skill: ", skill_name)
	
	# Unlock the skill for the player
	if player:
		player.unlock_skill(skill_name)

func _on_ability_chosen(ability_id: String) -> void:
	"""Called when player chooses an ability from ability up screen."""
	print("GameManager: Player chose ability: ", ability_id)
	
	# Apply the ability to the player
	if player:
		match ability_id:
			"attack_speed":
				player.increase_attack_speed(1.5)  # 50% faster attacks
			"crit_chance":
				player.add_crit_chance(0.20)  # 20% crit chance
			"cooldown_reduction":
				player.add_cooldown_reduction(0.25)  # 25% cooldown reduction
			_:
				push_warning("Unknown ability: " + ability_id)

func _on_relic_chosen(relic_id: String) -> void:
	"""Called when player chooses a relic at level 4."""
	print("GameManager: Player chose relic: ", relic_id)
	
	# Apply the relic to the player (permanent upgrades)
	if player:
		match relic_id:
			"double_jump":
				player.grant_double_jump()
			"dash":
				player.grant_dash()
			_:
				push_warning("Unknown relic: " + relic_id)

func _update_exp_display() -> void:
	"""Update the EXP bar and labels."""
	if not player:
		return
	
	# Update level label
	if level_label:
		level_label.text = "Level " + str(player.current_level)
	
	# Update EXP bar
	if exp_bar:
		exp_bar.max_value = player.exp_to_next_level
		exp_bar.value = player.current_exp
	
	# Update EXP label
	if exp_label:
		exp_label.text = str(player.current_exp) + " / " + str(player.exp_to_next_level) + " EXP"

func should_spawn_dummy() -> bool:
	"""Check if we should spawn a new dummy."""
	# Don't spawn if we've reached the max
	if active_dummies.size() >= MAX_DUMMIES:
		return false
	
	# Spawn if timer reached OR all dummies are dead
	return time_since_last_dummy_spawn >= DUMMY_SPAWN_INTERVAL or active_dummies.size() == 0

func _spawn_initial_dummies() -> void:
	"""Spawn dummies at all valid spawn locations at the start of the level."""
	# Get all spawn locations that don't already have a dummy
	var used_locations: Array = []
	
	# Check which locations are already occupied by the initial dummy
	if dummy:
		for loc in dummy_spawn_locations:
			if dummy.global_position.distance_to(loc) < 50:  # Close enough to consider occupied
				used_locations.append(loc)
				break
	
	# Spawn a dummy at each unused spawn location
	for spawn_pos in dummy_spawn_locations:
		# Skip if this location is already occupied
		var is_occupied = false
		for used_loc in used_locations:
			if spawn_pos.distance_to(used_loc) < 50:
				is_occupied = true
				break
		
		if not is_occupied:
			var new_dummy = Dummy.instantiate()
			add_child(new_dummy)
			
			new_dummy.global_position = spawn_pos
			new_dummy.z_index = 1
			
			# Track it
			active_dummies.append(new_dummy)
			new_dummy.tree_exited.connect(_on_dummy_died.bind(new_dummy))
			
			# Spawn animation - fade in
			new_dummy.modulate.a = 0.0
			new_dummy.scale = Vector2(0.5, 0.5)
			
			var spawn_tween = create_tween()
			spawn_tween.set_parallel(true)
			spawn_tween.tween_property(new_dummy, "modulate:a", 1.0, 0.5)
			spawn_tween.tween_property(new_dummy, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT)
			
			print("Spawned initial dummy at ", spawn_pos)
	
	print("Initial dummies spawned. Total active dummies: ", active_dummies.size())

func _check_dummy_at_position(pos: Vector2, threshold: float = 80.0) -> bool:
	"""Check if a dummy exists at the given position within threshold distance."""
	for dummy in active_dummies:
		if dummy and is_instance_valid(dummy):
			if dummy.global_position.distance_to(pos) < threshold:
				return true
	return false

func _get_offset_positions(base_pos: Vector2, offset_distance: float = 80.0) -> Dictionary:
	"""Get the left, right, and center positions for a spawn location."""
	var left_angle = deg_to_rad(-25)  # 25 degrees to the left
	var right_angle = deg_to_rad(25)  # 25 degrees to the right
	
	var left_pos = base_pos + Vector2(cos(left_angle), sin(left_angle)) * offset_distance
	var right_pos = base_pos + Vector2(cos(right_angle), sin(right_angle)) * offset_distance
	
	return {
		"center": base_pos,
		"left": left_pos,
		"right": right_pos
	}

func _spawn_new_dummy() -> void:
	"""Spawn a new dummy at a random spawn location with smart offset handling."""
	var new_dummy = Dummy.instantiate()
	add_child(new_dummy)
	
	# Get random spawn position
	var base_spawn_pos = dummy_spawn_locations[randi() % dummy_spawn_locations.size()]
	
	# Get all possible positions (center, left, right)
	var positions = _get_offset_positions(base_spawn_pos)
	
	# Check which positions are available
	var center_available = not _check_dummy_at_position(positions.center)
	var left_available = not _check_dummy_at_position(positions.left)
	var right_available = not _check_dummy_at_position(positions.right)
	
	var final_pos: Vector2
	
	# Prefer center if available
	if center_available:
		final_pos = positions.center
		print("Spawned dummy at center position: ", final_pos)
	elif left_available and right_available:
		# Both sides available, randomly choose one
		if randi() % 2 == 0:
			final_pos = positions.left
			print("Spawned dummy at left offset: ", final_pos)
		else:
			final_pos = positions.right
			print("Spawned dummy at right offset: ", final_pos)
	elif left_available:
		# Only left available
		final_pos = positions.left
		print("Spawned dummy at left offset: ", final_pos)
	elif right_available:
		# Only right available
		final_pos = positions.right
		print("Spawned dummy at right offset: ", final_pos)
	else:
		# All positions taken, use center anyway (or could skip spawning)
		final_pos = positions.center
		print("All positions occupied, spawning at center: ", final_pos)
	
	new_dummy.global_position = final_pos
	new_dummy.z_index = 1
	
	# Track it
	active_dummies.append(new_dummy)
	new_dummy.tree_exited.connect(_on_dummy_died.bind(new_dummy))
	
	# Reset spawn timer
	time_since_last_dummy_spawn = 0.0
	
	print("Spawned new dummy at ", final_pos, " | Active dummies: ", active_dummies.size())
	
	# Spawn animation - fade in
	new_dummy.modulate.a = 0.0
	new_dummy.scale = Vector2(0.5, 0.5)
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(new_dummy, "modulate:a", 1.0, 0.5)
	spawn_tween.tween_property(new_dummy, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT)

func _on_dummy_died(dummy_reference) -> void:
	"""Called when a dummy is destroyed."""
	if dummy_reference in active_dummies:
		active_dummies.erase(dummy_reference)
		print("Dummy died | Remaining: ", active_dummies.size())
