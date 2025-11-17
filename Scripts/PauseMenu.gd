extends CanvasLayer

## In-game pause menu with controls display

@onready var pause_panel: Panel = $PausePanel
@onready var controls_panel: Panel = $PausePanel/ControlsPanel
@onready var settings_panel: Panel = $PausePanel/InGameSettings
@onready var menu_container: VBoxContainer = $PausePanel/MenuContainer

var is_paused: bool = false
var settings_open: bool = false
var controls_open: bool = false
var can_pause: bool = false  # Start false, enable when game starts

func _ready() -> void:
	# Make sure this layer processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_menu()
	
	# Connect to game events to control when pausing is allowed
	EventBus.game_ended.connect(_on_game_ended)

func enable_pausing() -> void:
	"""Called by GameManager when game starts."""
	can_pause = true

func _on_game_ended(_total_damage: int, _total_hits: int) -> void:
	can_pause = false
	# If paused during game end, resume
	if is_paused:
		resume_game()

func _input(event: InputEvent) -> void:
	# Toggle pause with Escape key (only if pausing is allowed)
	if event.is_action_pressed("ui_cancel"):
		if settings_open:
			# Close settings and return to main pause menu
			settings_panel.visible = false
			menu_container.visible = true
			controls_panel.visible = false
			settings_open = false
		elif controls_open:
			# Close controls and return to main pause menu
			controls_panel.visible = false
			menu_container.visible = true
			controls_open = false
		elif is_paused:
			resume_game()
		elif can_pause:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	is_paused = true
	show_menu()
	EventBus.pause_game()

func resume_game() -> void:
	is_paused = false
	hide_menu()
	EventBus.resume_game()

func show_menu() -> void:
	pause_panel.visible = true
	# Show main menu, hide controls and settings
	menu_container.visible = true
	controls_panel.visible = false
	settings_panel.visible = false
	settings_open = false
	controls_open = false

func hide_menu() -> void:
	pause_panel.visible = false

func _on_resume_button_pressed() -> void:
	resume_game()

func _on_controls_button_pressed() -> void:
	controls_open = true
	# Hide main menu, show controls
	menu_container.visible = false
	controls_panel.visible = true
	settings_panel.visible = false

func _on_controls_back_button_pressed() -> void:
	controls_open = false
	# Hide controls, show main menu
	controls_panel.visible = false
	menu_container.visible = true

func _on_settings_button_pressed() -> void:
	settings_open = true
	# Hide main menu and controls, show settings
	menu_container.visible = false
	controls_panel.visible = false
	settings_panel.visible = true

func _on_main_menu_button_pressed() -> void:
	# Resume first so the game isn't paused in menu
	EventBus.resume_game()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

