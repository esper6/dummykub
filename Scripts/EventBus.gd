extends Node

## Minimal Global Event Bus
## This is a stripped-down version with only universal game events
## Extend this by adding your own signals based on your game's needs
## 
## Example usage:
##   EventBus.game_paused.emit()
##   EventBus.settings_changed.connect(_on_settings_changed)

# ============================================
# SYSTEM EVENTS - Universal to all games
# ============================================

## Emitted when the game is paused
signal game_paused()

## Emitted when the game is unpaused
signal game_resumed()

## Emitted when a setting is changed
## Parameters: setting_name (String), new_value (Variant)
signal settings_changed(setting_name: String, new_value)

## Emitted when the game is saved
signal game_saved()

## Emitted when a save is loaded
signal game_loaded()

# ============================================
# OPTIONAL: UI EVENTS
# ============================================
# Uncomment these if your game has window/panel management

## Emitted when a UI panel/window opens
# signal ui_opened(ui_name: String)

## Emitted when a UI panel/window closes
# signal ui_closed(ui_name: String)

## Emitted to show a notification/message to the player
# signal notification_requested(title: String, message: String)

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	pass

# ============================================
# CONVENIENCE METHODS (OPTIONAL)
# ============================================

## Pause the game
func pause_game() -> void:
	get_tree().paused = true
	game_paused.emit()

## Resume the game
func resume_game() -> void:
	get_tree().paused = false
	game_resumed.emit()

# ============================================
# GAME-SPECIFIC EVENTS - Dummykub
# ============================================

## Emitted when the player lands a hit on the dummy
signal hit_landed(damage: int)

## Emitted when the game timer ends
signal game_ended(total_damage: int, total_hits: int)

## Emitted when a combo is performed
signal combo_performed(combo_count: int)

## Emitted when a dummy spawns
signal dummy_spawned(dummy: Node2D)

## Emitted when a dummy dies
signal dummy_died(dummy: Node2D)
