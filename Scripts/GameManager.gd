extends Node2D

## Main game manager for Dummykub
## Manages the timer, score, and game state

@onready var player = $Player
@onready var dummy = $Dummy
@onready var ui_manager = $UIManager
@onready var timer_label: Label = $UI/TimerLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var damage_label: Label = $UI/DamageLabel
@onready var go_label: Label = $UI/GoLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var score_label: Label = $UI/GameOverPanel/VBoxContainer/ScoreLabel
@onready var hits_label: Label = $UI/GameOverPanel/VBoxContainer/HitsLabel

const GAME_DURATION: float = 60.0

var time_remaining: float = GAME_DURATION
var total_damage: int = 0
var total_hits: int = 0
var game_active: bool = false  # Start inactive until GO! animation finishes

func _ready() -> void:
	# Connect UI Manager to player cooldowns
	if ui_manager and player:
		ui_manager.setup_player_connections(player)
	
	# Connect to player signals
	if player:
		player.hit_landed.connect(_on_player_hit_landed)
	
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

func _on_player_hit_landed(damage: int) -> void:
	total_damage += damage
	total_hits += 1
	
	# Update UI
	combo_label.text = str(total_hits) + " HITS"
	damage_label.text = "Total: " + str(total_damage)
	
	# Apply damage to dummy
	if dummy:
		dummy.take_damage(damage)

func _end_game() -> void:
	game_active = false
	
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
