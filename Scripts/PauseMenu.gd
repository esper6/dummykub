extends CanvasLayer

## In-game pause menu with controls display

@onready var pause_panel: Panel = $PausePanel
@onready var controls_panel: Panel = $PausePanel/ControlsPanel
@onready var settings_panel: Panel = $PausePanel/InGameSettings
@onready var menu_container: VBoxContainer = $PausePanel/MenuContainer
var resume_button: Button = null
var controls_button: Button = null
var settings_button: Button = null
var stats_button: Button = null
var main_menu_button: Button = null

var is_paused: bool = false
var settings_open: bool = false
var controls_open: bool = false
var stats_open: bool = false
var can_pause: bool = false  # Start false, enable when game starts
var stat_up_screen: CanvasLayer = null  # Reference to stat screen (will be set from GameManager)
var player: Node = null  # Reference to player (will be set from GameManager)

func _ready() -> void:
	# Make sure this layer processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_menu()
	
	# Get button references
	resume_button = menu_container.get_node_or_null("ResumeButton")
	controls_button = menu_container.get_node_or_null("ControlsButton")
	settings_button = menu_container.get_node_or_null("SettingsButton")
	main_menu_button = menu_container.get_node_or_null("MainMenuButton")
	
	# Create Stats button if it doesn't exist
	stats_button = menu_container.get_node_or_null("StatsButton")
	if not stats_button:
		# Find where to insert it (after Settings, before Main Menu)
		var settings_index = -1
		for i in range(menu_container.get_child_count()):
			var child = menu_container.get_child(i)
			if child == settings_button:
				settings_index = i
				break
		
		stats_button = Button.new()
		stats_button.name = "StatsButton"
		stats_button.custom_minimum_size = Vector2(0, 60)
		stats_button.add_theme_font_size_override("font_size", 28)
		
		# Insert after Settings button
		if settings_index >= 0:
			menu_container.add_child(stats_button)
			menu_container.move_child(stats_button, settings_index + 1)
		else:
			menu_container.add_child(stats_button)
	
	# Update button text with icons
	_update_button_icons()
	
	# Connect stats button
	if stats_button:
		if not stats_button.pressed.is_connected(_on_stats_button_pressed):
			stats_button.pressed.connect(_on_stats_button_pressed)
	
	# Connect to game events to control when pausing is allowed
	EventBus.game_ended.connect(_on_game_ended)

func _update_button_icons() -> void:
	"""Update button text with icons."""
	if resume_button:
		resume_button.text = "✕ Resume"  # Red X icon
		resume_button.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red color
	if controls_button:
		controls_button.text = "🎮 Controls"  # Controller icon
	if settings_button:
		settings_button.text = "⚙ Settings"  # Gear icon
	if main_menu_button:
		main_menu_button.text = "⏻ Main Menu"  # Power button icon
	if stats_button:
		stats_button.text = "📊 Stats"  # Stats icon

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
		if stats_open:
			# Close stats and resume game
			if stat_up_screen:
				stat_up_screen.hide()
			resume_game()
		elif settings_open:
			# Close settings and return to stats screen (same as back button)
			settings_panel.visible = false
			controls_panel.visible = false
			menu_container.visible = false
			pause_panel.visible = false  # StatUpScreen has its own overlay
			settings_open = false
			if stat_up_screen and player:
				stat_up_screen.show_stats_display(player)
				stats_open = true
		elif controls_open:
			# Close controls and return to stats screen (same as back button)
			controls_panel.visible = false
			menu_container.visible = false
			pause_panel.visible = false  # StatUpScreen has its own overlay
			controls_open = false
			if stat_up_screen and player:
				stat_up_screen.show_stats_display(player)
				stats_open = true
		elif is_paused:
			resume_game()
		elif can_pause:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	is_paused = true
	# Show stats screen first instead of menu
	if stat_up_screen and player:
		stat_up_screen.show_stats_display(player)
		stats_open = true
		menu_container.visible = false
	else:
		show_menu()
	EventBus.pause_game()

func resume_game() -> void:
	is_paused = false
	hide_menu()
	EventBus.resume_game()

func show_menu() -> void:
	pause_panel.visible = true
	# Show main menu, hide controls, settings, and stats
	menu_container.visible = true
	controls_panel.visible = false
	settings_panel.visible = false
	if stat_up_screen:
		stat_up_screen.hide()
	settings_open = false
	controls_open = false
	stats_open = false

func hide_menu() -> void:
	pause_panel.visible = false
	# Hide stats screen if open
	if stat_up_screen:
		stat_up_screen.hide()
	stats_open = false

func _on_resume_button_pressed() -> void:
	resume_game()

func _on_controls_button_pressed() -> void:
	controls_open = true
	# Hide stats screen, show controls
	if stat_up_screen:
		stat_up_screen.hide()
	stats_open = false
	# Make sure pause panel is visible
	pause_panel.visible = true
	menu_container.visible = false
	controls_panel.visible = true
	settings_panel.visible = false

func _on_controls_back_button_pressed() -> void:
	controls_open = false
	# Hide controls and pause panel, show stats screen
	controls_panel.visible = false
	menu_container.visible = false
	pause_panel.visible = false  # StatUpScreen has its own overlay
	if stat_up_screen and player:
		stat_up_screen.show_stats_display(player)
		stats_open = true

func _on_settings_button_pressed() -> void:
	settings_open = true
	# Hide stats screen, show settings
	if stat_up_screen:
		stat_up_screen.hide()
	stats_open = false
	# Make sure pause panel is visible
	pause_panel.visible = true
	menu_container.visible = false
	controls_panel.visible = false
	settings_panel.visible = true

func _on_main_menu_button_pressed() -> void:
	# Resume first so the game isn't paused in menu
	EventBus.resume_game()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_stats_button_pressed() -> void:
	stats_open = true
	# Hide other panels, show stats
	menu_container.visible = false
	controls_panel.visible = false
	settings_panel.visible = false
	controls_open = false
	settings_open = false
	if stat_up_screen and player:
		stat_up_screen.show_stats_display(player)

func setup_stat_screen(stat_screen_ref: CanvasLayer, player_ref: Node) -> void:
	"""Called by GameManager to set up references."""
	stat_up_screen = stat_screen_ref
	player = player_ref
	# Connect pause menu to stat screen for button callbacks
	if stat_up_screen.has_method("setup_pause_menu"):
		stat_up_screen.setup_pause_menu(self)
