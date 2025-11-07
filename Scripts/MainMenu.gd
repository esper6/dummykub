extends Control

## Main Menu scene with Play, Continue, Settings, and Quit buttons

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# Check if there's a save file to enable/disable continue button
	if GameState.has_save_file():
		continue_button.disabled = false
		continue_button.theme_override_colors["font_color"] = Color(1, 1, 1, 1)
	else:
		continue_button.disabled = true
	
	# Focus the play button by default
	play_button.grab_focus()

func _on_play_button_pressed() -> void:
	# Start a new game
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_continue_button_pressed() -> void:
	# Load the saved game
	if GameState.load_progress():
		get_tree().change_scene_to_file("res://Scenes/Game.tscn")
	else:
		push_error("Failed to load save file")

func _on_settings_button_pressed() -> void:
	# Open settings menu
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

func _on_quit_button_pressed() -> void:
	# Quit the game
	get_tree().quit()

