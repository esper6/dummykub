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

const GAME_DURATION: float = 60.0
const POWERUP_SPAWN_INTERVAL: float = 10.0  # Spawn power-up every 10 seconds
const DUMMY_SPAWN_INTERVAL: float = 10.0  # Spawn dummy every 10 seconds
const MAX_DUMMIES: int = 3  # Maximum dummies at once

const DoubleJumpPowerup = preload("res://Scenes/DoubleJumpPowerup.tscn")
const DamageMultiplierPowerup = preload("res://Scenes/DamageMultiplierPowerup.tscn")
const ElementalImbue = preload("res://Scenes/ElementalImbue.tscn")
const NoCooldownPowerup = preload("res://Scenes/NoCooldownPowerup.tscn")
const Dummy = preload("res://Scenes/Dummy.tscn")

# Power-up pool for random spawning
var powerup_pool: Array = []

var time_remaining: float = GAME_DURATION
var total_damage: int = 0
var total_hits: int = 0
var game_active: bool = false  # Start inactive until GO! animation finishes

# Dummy spawning system
var active_dummies: Array = []
var time_since_last_dummy_spawn: float = 0.0
var dummy_spawn_locations: Array = [
	Vector2(600, 800),   # Left side
	Vector2(900, 700),   # Center upper
	Vector2(1500, 750),  # Far right
	Vector2(400, 750),   # Far left
	Vector2(1200, 800),  # Original position (right side)
]
var next_dummy_spawn_index: int = 0

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
var spawned_powerups: Array = []  # Track which power-ups have been spawned this round

func _ready() -> void:
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
	
	# Track the initial dummy
	if dummy:
		active_dummies.append(dummy)
		dummy.tree_exited.connect(_on_dummy_died.bind(dummy))
		print("Initial dummy tracked. Active dummies: ", active_dummies.size())
	
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
	
	# Show game over panel
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
	# Initialize power-up pool (equal weight for all)
	if powerup_pool.is_empty():
		powerup_pool = [
			DoubleJumpPowerup,
			DamageMultiplierPowerup,
			ElementalImbue,
			NoCooldownPowerup
		]
	
	# Build available pool (excluding already spawned one-time power-ups)
	var available_pool: Array = []
	for powerup_scene in powerup_pool:
		# Check if this is DoubleJump and if it's already been spawned
		if powerup_scene == DoubleJumpPowerup and DoubleJumpPowerup in spawned_powerups:
			continue  # Skip double jump if already spawned this round
		available_pool.append(powerup_scene)
	
	# If no power-ups available, don't spawn
	if available_pool.is_empty():
		print("No power-ups available to spawn")
		return
	
	# Pick a random power-up from available pool
	var random_powerup_scene = available_pool[randi() % available_pool.size()]
	var powerup = random_powerup_scene.instantiate()
	add_child(powerup)
	
	# Track that this power-up type has been spawned
	if random_powerup_scene == DoubleJumpPowerup:
		spawned_powerups.append(DoubleJumpPowerup)
	
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

func _on_skill_chosen(skill_name: String) -> void:
	"""Called when player chooses a skill from level up screen."""
	print("GameManager: Player chose skill: ", skill_name)
	
	# Unlock the skill for the player
	if player:
		player.unlock_skill(skill_name)

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

func _spawn_new_dummy() -> void:
	"""Spawn a new dummy at the next spawn location."""
	var new_dummy = Dummy.instantiate()
	add_child(new_dummy)
	
	# Get spawn position (cycle through locations)
	var spawn_pos = dummy_spawn_locations[next_dummy_spawn_index]
	next_dummy_spawn_index = (next_dummy_spawn_index + 1) % dummy_spawn_locations.size()
	
	new_dummy.global_position = spawn_pos
	new_dummy.z_index = 1
	
	# Track it
	active_dummies.append(new_dummy)
	new_dummy.tree_exited.connect(_on_dummy_died.bind(new_dummy))
	
	# Reset spawn timer
	time_since_last_dummy_spawn = 0.0
	
	print("Spawned new dummy at ", spawn_pos, " | Active dummies: ", active_dummies.size())
	
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
