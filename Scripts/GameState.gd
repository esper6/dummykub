extends Node

## Minimal Game State Manager
## Handles settings persistence and game progress tracking
## Extend this with your game-specific data

signal settings_changed(setting_name: String, new_value)

# ============================================
# GAME PROGRESS (Customize for your game)
# ============================================

# Example progress tracking - modify for your game type:
var current_level: String = ""
var checkpoints_reached: Array[String] = []
var unlocked_content: Dictionary = {}

# ============================================
# USER SETTINGS (Universal)
# ============================================

var settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
	"fullscreen": false,
	"vsync": true
}

const SETTINGS_FILE_PATH: String = "user://settings.json"
const PROGRESS_FILE_PATH: String = "user://progress.json"

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	load_settings()

# ============================================
# SETTINGS MANAGEMENT
# ============================================

## Get a setting value with optional default
func get_setting(setting_name: String, default_value = null):
	return settings.get(setting_name, default_value)

## Update a setting and save
func set_setting(setting_name: String, value) -> void:
	settings[setting_name] = value
	settings_changed.emit(setting_name, value)
	
	# Notify EventBus if it exists
	if EventBus:
		EventBus.settings_changed.emit(setting_name, value)
	
	save_settings()

## Reset all settings to defaults
func reset_settings_to_default() -> void:
	settings = {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0,
		"fullscreen": false,
		"vsync": true
	}
	save_settings()

# ============================================
# SETTINGS PERSISTENCE
# ============================================

## Save settings to disk
func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(settings, "\t")
		file.store_string(json_string)
		file.close()
	else:
		push_error("[GameState] Failed to save settings")

## Load settings from disk
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[GameState] Failed to open settings file")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result == OK:
		var loaded_settings = json.data
		# Merge with defaults (preserves new settings if version changes)
		for key in loaded_settings:
			settings[key] = loaded_settings[key]
	else:
		push_error("[GameState] Failed to parse settings JSON")

# ============================================
# GAME PROGRESS (Customize for your game)
# ============================================

## Save game progress
func save_progress() -> void:
	var progress_data := {
		"current_level": current_level,
		"checkpoints": checkpoints_reached,
		"unlocked": unlocked_content
	}
	
	var file := FileAccess.open(PROGRESS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(progress_data, "\t")
		file.store_string(json_string)
		file.close()
		
		if EventBus:
			EventBus.game_saved.emit()
		
	else:
		push_error("[GameState] Failed to save progress")

## Load game progress
func load_progress() -> bool:
	if not FileAccess.file_exists(PROGRESS_FILE_PATH):
		return false
	
	var file := FileAccess.open(PROGRESS_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[GameState] Failed to open progress file")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result == OK:
		var progress_data = json.data
		current_level = progress_data.get("current_level", "")
		checkpoints_reached = progress_data.get("checkpoints", [])
		unlocked_content = progress_data.get("unlocked", {})
		
		if EventBus:
			EventBus.game_loaded.emit()
		
		return true
	else:
		push_error("[GameState] Failed to parse progress JSON")
		return false

## Check if a save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(PROGRESS_FILE_PATH)

## Delete save file
func delete_save_file() -> void:
	if has_save_file():
		DirAccess.remove_absolute(PROGRESS_FILE_PATH)

# ============================================
# EXAMPLE: PROGRESS TRACKING METHODS
# ============================================
# Customize these for your game type

## Mark content as unlocked
func unlock_content(content_id: String) -> void:
	unlocked_content[content_id] = true

## Check if content is unlocked
func is_unlocked(content_id: String) -> bool:
	return unlocked_content.get(content_id, false)

## Add a checkpoint
func add_checkpoint(checkpoint_id: String) -> void:
	if not checkpoints_reached.has(checkpoint_id):
		checkpoints_reached.append(checkpoint_id)
