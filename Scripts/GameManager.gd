extends Node2D

## Main game manager for Dummykub
## Manages the timer, score, and game state

@onready var player = $Player
@onready var dummy = $Dummy
@onready var timer_label: Label = $UI/TimerLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var damage_label: Label = $UI/DamageLabel
@onready var game_over_panel: Panel = $UI/GameOverPanel
@onready var score_label: Label = $UI/GameOverPanel/VBoxContainer/ScoreLabel
@onready var hits_label: Label = $UI/GameOverPanel/VBoxContainer/HitsLabel

const GAME_DURATION: float = 60.0

var time_remaining: float = GAME_DURATION
var total_damage: int = 0
var total_hits: int = 0
var game_active: bool = true

func _ready() -> void:
	# Connect to player signals
	if player:
		player.hit_landed.connect(_on_player_hit_landed)
	
	game_over_panel.hide()

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

