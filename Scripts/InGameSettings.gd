extends Panel

## In-game settings panel that works within the pause menu

@onready var master_slider: HSlider = $MarginContainer/VBoxContainer/MasterVolumeContainer/Slider
@onready var master_label: Label = $MarginContainer/VBoxContainer/MasterVolumeContainer/ValueLabel
@onready var sfx_slider: HSlider = $MarginContainer/VBoxContainer/SFXVolumeContainer/Slider
@onready var sfx_label: Label = $MarginContainer/VBoxContainer/SFXVolumeContainer/ValueLabel
@onready var music_slider: HSlider = $MarginContainer/VBoxContainer/MusicVolumeContainer/Slider
@onready var music_label: Label = $MarginContainer/VBoxContainer/MusicVolumeContainer/ValueLabel
@onready var fullscreen_check: CheckButton = $MarginContainer/VBoxContainer/FullscreenCheck
@onready var vsync_check: CheckButton = $MarginContainer/VBoxContainer/VSyncCheck

func _ready() -> void:
	# Load current settings
	master_slider.value = GameState.get_setting("master_volume", 1.0)
	sfx_slider.value = GameState.get_setting("sfx_volume", 1.0)
	music_slider.value = GameState.get_setting("music_volume", 1.0)
	fullscreen_check.button_pressed = GameState.get_setting("fullscreen", false)
	vsync_check.button_pressed = GameState.get_setting("vsync", true)
	
	# Update labels
	_update_volume_label(master_label, master_slider.value)
	_update_volume_label(sfx_label, sfx_slider.value)
	_update_volume_label(music_label, music_slider.value)
	
	# Start hidden
	visible = false

func _update_volume_label(label: Label, value: float) -> void:
	label.text = str(int(value * 100)) + "%"

func _on_master_volume_changed(value: float) -> void:
	GameState.set_setting("master_volume", value)
	_update_volume_label(master_label, value)
	# TODO: Apply to AudioServer when we add audio

func _on_sfx_volume_changed(value: float) -> void:
	GameState.set_setting("sfx_volume", value)
	_update_volume_label(sfx_label, value)
	# TODO: Apply to AudioServer when we add audio

func _on_music_volume_changed(value: float) -> void:
	GameState.set_setting("music_volume", value)
	_update_volume_label(music_label, value)
	# TODO: Apply to AudioServer when we add audio

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	GameState.set_setting("fullscreen", button_pressed)
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(button_pressed: bool) -> void:
	GameState.set_setting("vsync", button_pressed)
	if button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_back_button_pressed() -> void:
	visible = false
	# Show the stats screen again (hide controls and menu)
	var pause_panel = get_parent()  # This is PausePanel
	if pause_panel:
		pause_panel.get_node("MenuContainer").visible = false
		pause_panel.get_node("ControlsPanel").visible = false
		pause_panel.visible = false  # StatUpScreen has its own overlay
		# Update the parent PauseMenu's settings_open flag and show stats
		var pause_menu = pause_panel.get_parent()
		if pause_menu and pause_menu.has_method("enable_pausing"):
			pause_menu.settings_open = false
			# Show stats screen if available
			# Access properties directly since they're public variables
			if pause_menu.stat_up_screen and pause_menu.player:
				pause_menu.stat_up_screen.show_stats_display(pause_menu.player)
				pause_menu.stats_open = true
