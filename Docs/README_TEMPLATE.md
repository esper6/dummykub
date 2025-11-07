# Godot Game Template - Minimal Architecture

A lightweight, reusable architecture for Godot 4.x games with event-driven design and persistent settings.

## 🎯 What's Included

This template provides:
- ✅ **EventBus** - Decoupled event system for clean communication
- ✅ **GameState** - Settings management and save/load system
- ✅ **Documentation** - Clear guides for extending the systems
- ✅ **Best Practices** - Coding standards and patterns

## 📁 Template Structure

```
YourGame/
├── Scripts/
│   ├── EventBus.gd          # Global event system (autoload)
│   └── GameState.gd         # Settings & save system (autoload)
├── docs/
│   └── EVENT_SYSTEM.md      # How to use and extend EventBus
└── .cursor/
    └── rules/
        └── quality-and-style.md  # Code standards
```

## 🚀 Quick Start

### 1. Copy Files to Your Project

Copy these files:
- `Scripts/EventBus.gd` (from `EventBus_Minimal.gd`)
- `Scripts/GameState.gd` (from `GameState_Minimal.gd`)
- `docs/` folder
- `.cursor/rules/` folder (optional but recommended)

### 2. Set Up Autoloads

In Godot: **Project Settings > Autoload**

Add these in order:
1. **GameStateManager** → `res://Scripts/GameState.gd`
2. **EventBus** → `res://Scripts/EventBus.gd`

### 3. Extend EventBus for Your Game

Open `Scripts/EventBus.gd` and add signals for your game type:

**For a Platformer:**
```gdscript
signal player_died()
signal checkpoint_reached(checkpoint_id: String)
signal coin_collected(amount: int)
```

**For an RPG:**
```gdscript
signal enemy_defeated(enemy_id: String)
signal level_up(new_level: int)
signal quest_completed(quest_id: String)
```

**For a Puzzle Game:**
```gdscript
signal puzzle_completed(puzzle_id: String)
signal move_made(move_data: Dictionary)
signal hint_requested()
```

### 4. Use Events in Your Game

**Emit events when things happen:**
```gdscript
# In your player script
func die():
	EventBus.player_died.emit()
```

**Listen for events in other systems:**
```gdscript
# In your UI script
func _ready():
	EventBus.player_died.connect(_on_player_died)

func _on_player_died():
	show_game_over_screen()
```

## 📚 Core Concepts

### Event-Driven Architecture

Instead of this (tight coupling):
```gdscript
func collect_coin():
	get_node("/root/Main/HUD").update_score()
	get_node("/root/Main/AudioManager").play_sound("coin")
```

Do this (loose coupling):
```gdscript
func collect_coin():
	EventBus.coin_collected.emit(10)
```

**Benefits:**
- Components don't need to know about each other
- Easy to add/remove systems
- Easier to test
- More maintainable

### Settings Management

**Get a setting:**
```gdscript
var volume = GameStateManager.get_setting("master_volume", 1.0)
```

**Change a setting:**
```gdscript
GameStateManager.set_setting("master_volume", 0.8)
# Automatically saves to disk!
```

**Listen for changes:**
```gdscript
func _ready():
	GameStateManager.settings_changed.connect(_on_setting_changed)

func _on_setting_changed(setting_name: String, new_value):
	if setting_name == "master_volume":
		AudioServer.set_bus_volume_db(0, linear_to_db(new_value))
```

### Save/Load System

**Save progress:**
```gdscript
GameStateManager.save_progress()
# EventBus.game_saved is emitted automatically
```

**Load progress:**
```gdscript
if GameStateManager.has_save_file():
	GameStateManager.load_progress()
	# EventBus.game_loaded is emitted automatically
```

## 🎨 Customization Guide

### Add Game-Specific Settings

In `GameState.gd`, update the `settings` dictionary:

```gdscript
var settings: Dictionary = {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
	"fullscreen": false,
	"vsync": true,
	# Add your settings:
	"difficulty": "normal",
	"controls_scheme": "keyboard",
	"show_tutorial": true
}
```

Also update `reset_settings_to_default()` with the same values.

### Add Progress Tracking

In `GameState.gd`, customize the progress variables:

**For a Platformer:**
```gdscript
var current_level: String = "level_1"
var collected_stars: int = 0
var unlocked_levels: Array[String] = ["level_1"]
var best_times: Dictionary = {}
```

**For an RPG:**
```gdscript
var player_level: int = 1
var player_xp: int = 0
var completed_quests: Array[String] = []
var inventory: Dictionary = {}
var party_members: Array[String] = []
```

Update `save_progress()` and `load_progress()` to include your data.

### Add Custom Events

See `docs/EVENT_SYSTEM.md` for detailed examples of events for different game types.

## 🎮 Example Patterns

### Achievement System

```gdscript
# AchievementManager.gd
extends Node

var achievements := {
	"first_death": false,
	"speed_runner": false,
}

func _ready():
	EventBus.player_died.connect(_check_first_death)
	EventBus.level_completed.connect(_check_speed_run)

func _check_first_death():
	if not achievements["first_death"]:
		achievements["first_death"] = true
		show_achievement("First Death", "Everyone starts somewhere!")

func _check_speed_run(level_name: String, time: float):
	if time < 60.0 and not achievements["speed_runner"]:
		achievements["speed_runner"] = true
		show_achievement("Speed Runner", "Complete a level in under 60 seconds!")
```

### Audio Manager

```gdscript
# AudioManager.gd
extends Node

@onready var music_player := $MusicPlayer
@onready var sfx_player := $SFXPlayer

func _ready():
	EventBus.settings_changed.connect(_on_setting_changed)
	EventBus.player_died.connect(_play_death_sound)
	EventBus.coin_collected.connect(_play_coin_sound)
	
	# Apply initial volumes
	_update_volumes()

func _on_setting_changed(setting_name: String, _new_value):
	if setting_name.ends_with("_volume"):
		_update_volumes()

func _update_volumes():
	var master = GameStateManager.get_setting("master_volume", 1.0)
	var music = GameStateManager.get_setting("music_volume", 1.0)
	var sfx = GameStateManager.get_setting("sfx_volume", 1.0)
	
	music_player.volume_db = linear_to_db(master * music)
	sfx_player.volume_db = linear_to_db(master * sfx)

func _play_death_sound():
	sfx_player.stream = preload("res://audio/death.ogg")
	sfx_player.play()

func _play_coin_sound(_amount: int):
	sfx_player.stream = preload("res://audio/coin.ogg")
	sfx_player.play()
```

## 📖 Documentation

- **[Event System Guide](docs/EVENT_SYSTEM.md)** - Complete EventBus documentation
- **[Code Style Guide](.cursor/rules/quality-and-style.md)** - Best practices

## 🔧 Philosophy

This template follows these principles:

1. **Minimal by Default** - Only includes universal features
2. **Easy to Extend** - Clear patterns for adding your game's needs
3. **Decoupled Design** - Systems communicate through events
4. **Well Documented** - Every pattern is explained
5. **Production Ready** - Battle-tested architecture

## 🎯 What This Template Is NOT

This is **not** a full game framework. It doesn't include:
- ❌ UI components
- ❌ Character controllers
- ❌ Inventory systems
- ❌ Dialogue boxes
- ❌ Combat systems

**Why?** Because every game is different! This template gives you the **architecture foundation** to build any game type cleanly.

## 🚧 Next Steps

1. **Add your game-specific events** to EventBus
2. **Customize GameState** with your progress data
3. **Build your game systems** using these patterns
4. **Connect everything with events** for clean code

## 💡 Tips

- Start small - add events as you need them
- Use EventBus for cross-system communication
- Use direct signals for parent-child UI elements
- Document your custom events
- Save settings automatically (it's built-in!)

## 📝 License

This template is provided as-is for any use. No attribution required.

---

**Happy Game Development! 🎮**

If you have questions about extending this template, check the documentation in `docs/`.

