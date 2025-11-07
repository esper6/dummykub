# Minimal Event System Documentation

## Overview

The **EventBus** is a global autoload singleton that provides centralized event communication for your game. This is a **minimal, universal version** that works for any game type.

## Philosophy: Start Small, Extend as Needed

This EventBus includes only the most universal events that apply to **any game**:
- Game state (pause/resume)
- Settings management
- Save/load system

**Everything else is added by you based on your game's needs.**

---

## Why Use EventBus?

### Without EventBus (Tight Coupling):
```gdscript
# Component needs direct references to other systems
func _on_player_died():
	get_node("/root/Main/GameManager").handle_death()
	get_node("/root/UI/HUD").show_game_over()
	get_node("/root/AudioManager").play_sound("death")
```

❌ Problems:
- Hard to maintain
- Breaks if node structure changes
- Components are tightly coupled
- Hard to test

### With EventBus (Loose Coupling):
```gdscript
# Component just emits an event
func _on_player_died():
	EventBus.player_died.emit()
```

✅ Benefits:
- Clean and simple
- Any system can listen for this event
- Easy to add/remove listeners
- Components are independent

---

## Core Events (Built-in)

### System Events

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `game_paused` | - | Game has been paused |
| `game_resumed` | - | Game has been unpaused |
| `settings_changed` | `setting_name: String, new_value` | A setting was changed |
| `game_saved` | - | Game progress was saved |
| `game_loaded` | - | Save data was loaded |

**Example:**
```gdscript
# Emit
EventBus.game_paused.emit()

# Listen
EventBus.game_paused.connect(_on_game_paused)

func _on_game_paused():
	print("Game paused - disable input")
	disable_player_controls()
```

### Convenience Methods

```gdscript
# Pause game (sets tree.paused = true and emits signal)
EventBus.pause_game()

# Resume game
EventBus.resume_game()
```

---

## How to Extend EventBus

### Step 1: Add Signals for Your Game

Open `Scripts/EventBus.gd` and add signals specific to your game type:

#### For RPG/Combat Games:
```gdscript
# Add to EventBus.gd
signal enemy_defeated(enemy_id: String)
signal player_damaged(damage: int, source: String)
signal item_collected(item_id: String)
signal level_up(new_level: int)
signal quest_completed(quest_id: String)
```

#### For Puzzle Games:
```gdscript
# Add to EventBus.gd
signal puzzle_started(puzzle_id: String)
signal puzzle_completed(puzzle_id: String)
signal move_made(from: Vector2, to: Vector2)
signal hint_used(puzzle_id: String)
```

#### For Platformers:
```gdscript
# Add to EventBus.gd
signal player_died()
signal player_respawned()
signal checkpoint_reached(checkpoint_id: String)
signal collectible_obtained(collectible_type: String)
signal level_completed(level_name: String)
```

#### For Visual Novel/Narrative Games:
```gdscript
# Add to EventBus.gd
signal dialogue_started(dialogue_id: String)
signal dialogue_ended()
signal choice_presented(choices: Array)
signal choice_selected(choice_id: String)
signal character_met(character_id: String)
```

#### For Strategy Games:
```gdscript
# Add to EventBus.gd
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
signal unit_spawned(unit_id: String, position: Vector2)
signal unit_moved(unit_id: String, position: Vector2)
signal resource_changed(resource_type: String, amount: int)
```

### Step 2: Use Your Custom Events

```gdscript
# Emit the event
EventBus.player_died.emit()

# Listen for the event
func _ready():
	EventBus.player_died.connect(_on_player_died)

func _on_player_died():
	show_game_over_screen()
```

---

## Basic Usage Patterns

### 1. Emitting Events

```gdscript
# Simple emit (no parameters)
EventBus.game_paused.emit()

# With parameters
EventBus.settings_changed.emit("volume", 0.8)

# Multiple parameters
EventBus.enemy_defeated.emit("goblin_01", 100)  # enemy_id, xp_reward
```

### 2. Listening to Events

```gdscript
func _ready():
	# Connect to event
	EventBus.game_saved.connect(_on_game_saved)
	
	# One-shot connection (auto-disconnects after first call)
	EventBus.game_loaded.connect(_on_first_load, CONNECT_ONE_SHOT)

func _on_game_saved():
	print("Save complete!")

func _on_first_load():
	print("First load only")
```

### 3. Disconnecting

```gdscript
func _exit_tree():
	# Clean up when node is removed
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)
```

**Note:** Godot auto-disconnects when nodes are freed, but manual cleanup is good practice for persistent objects.

---

## Best Practices

### ✅ DO: Use for Cross-System Communication

```gdscript
# Good: Decoupled systems
EventBus.enemy_defeated.emit("goblin_01")
```

### ❌ DON'T: Use for Parent-Child Communication

```gdscript
# Bad: EventBus is overkill for UI elements
button.pressed.connect(func(): EventBus.button_clicked.emit())

# Good: Direct connection for parent-child
button.pressed.connect(_on_button_pressed)
```

### ✅ DO: Use Descriptive Signal Names

```gdscript
# Good
signal enemy_defeated(enemy_id: String)

# Bad
signal thing_happened(data: String)
```

### ✅ DO: Document Your Signals

```gdscript
## Emitted when the player takes damage
## Parameters: damage (int), source_name (String)
signal player_damaged(damage: int, source: String)
```

### ✅ DO: Keep It Simple

Only add signals you actually need. Don't create signals "just in case."

---

## Common Patterns

### Pattern 1: Achievement System

```gdscript
# AchievementTracker.gd
extends Node

func _ready():
	EventBus.enemy_defeated.connect(_track_kills)
	EventBus.level_completed.connect(_track_completion)

var enemy_kills: int = 0

func _track_kills(enemy_id: String):
	enemy_kills += 1
	if enemy_kills >= 10:
		unlock_achievement("first_blood_10")

func _track_completion(level_name: String):
	unlock_achievement("complete_" + level_name)
```

### Pattern 2: State Machine

```gdscript
# GameStateManager.gd
enum State { MENU, PLAYING, PAUSED, GAME_OVER }
var current_state = State.MENU

func _ready():
	EventBus.game_paused.connect(func(): change_state(State.PAUSED))
	EventBus.game_resumed.connect(func(): change_state(State.PLAYING))

func change_state(new_state: State):
	current_state = new_state
	match current_state:
		State.PAUSED:
			show_pause_menu()
		State.PLAYING:
			hide_pause_menu()
```

### Pattern 3: Audio Manager

```gdscript
# AudioManager.gd
extends Node

@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

func _ready():
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.settings_changed.connect(_on_settings_changed)

func _on_player_damaged(damage: int, source: String):
	sfx_player.stream = load("res://audio/hurt.ogg")
	sfx_player.play()

func _on_enemy_defeated(enemy_id: String):
	sfx_player.stream = load("res://audio/victory.ogg")
	sfx_player.play()

func _on_settings_changed(setting_name: String, new_value):
	if setting_name == "sfx_volume":
		sfx_player.volume_db = linear_to_db(new_value)
```

### Pattern 4: UI Updates

```gdscript
# HUD.gd
extends Control

@onready var status_label: Label = $StatusLabel

func _ready():
	EventBus.player_damaged.connect(_update_status)
	EventBus.item_collected.connect(_update_status)

func _update_status(_param1 = null, _param2 = null):
	# Update UI to reflect game state
	status_label.text = "HP: %d | Items: %d" % [player.hp, player.item_count]
```

---

## Example: Building a Platformer EventBus

Here's a complete example for a platformer:

```gdscript
extends Node

# System Events (from minimal template)
signal game_paused()
signal game_resumed()
signal settings_changed(setting_name: String, new_value)
signal game_saved()
signal game_loaded()

# Platformer-specific events
signal player_died()
signal player_respawned(position: Vector2)
signal checkpoint_reached(checkpoint_id: String)
signal coin_collected(coin_value: int)
signal level_started(level_name: String)
signal level_completed(level_name: String, time: float)
signal enemy_stomped(enemy_type: String)

func _ready() -> void:
	print("[EventBus] Platformer EventBus ready")

# Convenience methods
func pause_game() -> void:
	get_tree().paused = true
	game_paused.emit()

func resume_game() -> void:
	get_tree().paused = false
	game_resumed.emit()
```

---

## Debugging

### Print All Events

Add to `EventBus._ready()`:

```gdscript
# Debug: Print all signal emissions
for sig in get_signal_list():
	var callable = func(args): print("[EventBus] %s emitted" % sig.name)
	connect(sig.name, callable)
```

### Check Connections

```gdscript
if EventBus.player_died.is_connected(_on_player_died):
	print("Already connected!")

var connections = EventBus.player_died.get_connections()
print("player_died has ", connections.size(), " listeners")
```

---

## Performance

- ✅ Signals are **very fast** in Godot
- ✅ EventBus adds minimal overhead
- ✅ Safe to use in `_process()` if needed
- ⚠️ Avoid emitting hundreds of events per frame
- ⚠️ Don't create circular dependencies (A triggers B, B triggers A)

---

## Summary

1. **Start with the minimal EventBus** (only system events)
2. **Add signals specific to your game type** as you need them
3. **Emit events** when important things happen
4. **Connect listeners** in systems that need to respond
5. **Keep it simple** - only add what you actually use

This approach keeps your codebase clean and prevents event bloat!

---

## Next Steps

- Copy `EventBus_Minimal.gd` to your project
- Add it as an autoload in Project Settings
- Add 2-3 signals specific to your game
- Start emitting and listening to events
- Add more signals as needed

Happy coding! 🎮

