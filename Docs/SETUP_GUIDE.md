# Setup Guide - Godot Minimal Template

## 📦 What You Have

This template contains:
```
Templates/
├── EventBus_Minimal.gd          # Global event system
├── GameState_Minimal.gd         # Settings & save system
├── EVENT_SYSTEM_MINIMAL.md      # Complete EventBus guide
├── README_TEMPLATE.md           # Template documentation
├── .cursor/
│   └── rules/
│       └── quality-and-style.md # Code standards
└── SETUP_GUIDE.md              # This file!
```

## 🚀 Installation Steps

### Step 1: Create Your Project Folders

In your new Godot project, create:
```
YourNewProject/
├── Scripts/
├── docs/
└── .cursor/
    └── rules/
```

### Step 2: Copy and Rename Files

Copy from the template:

1. **EventBus_Minimal.gd** → Copy to `Scripts/EventBus.gd`
2. **GameState_Minimal.gd** → Copy to `Scripts/GameState.gd`
3. **EVENT_SYSTEM_MINIMAL.md** → Copy to `docs/EVENT_SYSTEM.md`
4. **README_TEMPLATE.md** → Copy to your project root as `README.md` (edit as needed)
5. **quality-and-style.md** → Copy to `.cursor/rules/quality-and-style.md`

### Step 3: Configure Autoloads

In Godot Editor:
1. Open **Project → Project Settings**
2. Go to **Autoload** tab
3. Add these autoloads **in this order**:

| Name | Path | Enabled |
|------|------|---------|
| `GameStateManager` | `res://Scripts/GameState.gd` | ✓ |
| `EventBus` | `res://Scripts/EventBus.gd` | ✓ |

Click **Add** for each one.

### Step 4: Verify Installation

Create a test script to verify everything works:

```gdscript
# TestSetup.gd
extends Node

func _ready():
	# Test EventBus
	if EventBus:
		print("✓ EventBus loaded successfully")
		EventBus.game_paused.connect(func(): print("✓ EventBus signals working"))
		EventBus.game_paused.emit()
	else:
		print("✗ EventBus not found")
	
	# Test GameState
	if GameStateManager:
		print("✓ GameStateManager loaded successfully")
		GameStateManager.set_setting("test_setting", 123)
		var value = GameStateManager.get_setting("test_setting")
		if value == 123:
			print("✓ GameState settings working")
		else:
			print("✗ GameState settings not working")
	else:
		print("✗ GameStateManager not found")
	
	print("\n=== Setup Complete! ===")
```

Attach this to a test scene and run it. You should see all checkmarks (✓).

## 🎯 Next Steps: Customize for Your Game

### For a Platformer

**Add to EventBus.gd:**
```gdscript
signal player_died()
signal player_respawned(position: Vector2)
signal checkpoint_reached(checkpoint_id: String)
signal coin_collected(amount: int)
signal enemy_defeated(enemy_type: String)
signal level_started(level_name: String)
signal level_completed(level_name: String, time: float)
```

**Add to GameState.gd:**
```gdscript
# In the variable declarations section:
var current_level: String = "level_1"
var total_coins: int = 0
var unlocked_levels: Array[String] = ["level_1"]
var best_times: Dictionary = {}

# Update save_progress():
func save_progress() -> void:
	var progress_data := {
		"current_level": current_level,
		"total_coins": total_coins,
		"unlocked_levels": unlocked_levels,
		"best_times": best_times
	}
	# ... rest of save code

# Update load_progress():
func load_progress() -> bool:
	# ... JSON parsing code
	if parse_result == OK:
		var progress_data = json.data
		current_level = progress_data.get("current_level", "level_1")
		total_coins = progress_data.get("total_coins", 0)
		unlocked_levels = progress_data.get("unlocked_levels", ["level_1"])
		best_times = progress_data.get("best_times", {})
	# ... rest of load code
```

### For an RPG

**Add to EventBus.gd:**
```gdscript
signal enemy_defeated(enemy_id: String, xp_gained: int)
signal player_damaged(damage: int, source: String)
signal player_healed(amount: int)
signal level_up(new_level: int)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal item_collected(item_id: String)
signal item_equipped(item_id: String, slot: String)
```

**Add to GameState.gd:**
```gdscript
var player_level: int = 1
var player_xp: int = 0
var player_hp: int = 100
var player_max_hp: int = 100
var inventory: Dictionary = {}
var equipped_items: Dictionary = {}
var completed_quests: Array[String] = []
var active_quests: Array[String] = []
```

### For a Puzzle Game

**Add to EventBus.gd:**
```gdscript
signal puzzle_started(puzzle_id: String)
signal puzzle_completed(puzzle_id: String, moves: int, time: float)
signal move_made(from: Vector2, to: Vector2)
signal move_undone()
signal hint_requested(puzzle_id: String)
signal hint_used(puzzle_id: String)
```

**Add to GameState.gd:**
```gdscript
var completed_puzzles: Dictionary = {}  # puzzle_id: {moves, time, stars}
var current_puzzle: String = ""
var total_hints_used: int = 0
var total_stars: int = 0
```

## 📋 Common Tasks

### Add a New Event

1. Open `Scripts/EventBus.gd`
2. Add signal with documentation:
```gdscript
## Emitted when the player collects a coin
## Parameters: amount (int) - Value of the coin
signal coin_collected(amount: int)
```
3. Use it anywhere:
```gdscript
EventBus.coin_collected.emit(10)
```

### Add a New Setting

1. Open `Scripts/GameState.gd`
2. Add to the `settings` dictionary:
```gdscript
var settings: Dictionary = {
	# ... existing settings
	"show_fps": false,  # Your new setting
}
```
3. Also add to `reset_settings_to_default()`
4. Use it:
```gdscript
var show_fps = GameStateManager.get_setting("show_fps", false)
```

### Save/Load Custom Data

**Save:**
```gdscript
func save_game():
	# Update GameState with your data
	GameStateManager.current_level = current_level_name
	GameStateManager.total_coins = coins
	
	# Save to disk
	GameStateManager.save_progress()
```

**Load:**
```gdscript
func load_game():
	if GameStateManager.load_progress():
		current_level_name = GameStateManager.current_level
		coins = GameStateManager.total_coins
		# Load level scene, etc.
```

## 🐛 Troubleshooting

### "EventBus not found" error

**Problem:** Autoload not configured
**Solution:** Go to Project Settings → Autoload and add `EventBus` pointing to `res://Scripts/EventBus.gd`

### Settings not saving

**Check:**
1. Is `GameStateManager` in autoloads?
2. Check the Godot console for error messages
3. Settings save to `user://settings.json` - check this location:
   - **Windows:** `%APPDATA%\Godot\app_userdata\YourProjectName\`
   - **Linux:** `~/.local/share/godot/app_userdata/YourProjectName/`
   - **macOS:** `~/Library/Application Support/Godot/app_userdata/YourProjectName/`

### Signal not firing

**Debug:**
```gdscript
# Check if signal exists
if EventBus.has_signal("player_died"):
	print("Signal exists")

# Check connections
var connections = EventBus.player_died.get_connections()
print("Listeners: ", connections.size())

# Print when signal emits
EventBus.player_died.connect(func(): print("Signal fired!"))
```

## 📚 Learn More

- Read `docs/EVENT_SYSTEM.md` for complete EventBus documentation
- Read `README.md` for architecture overview and patterns
- Check `.cursor/rules/quality-and-style.md` for code standards

## ✅ Checklist

After setup, you should have:
- [x] EventBus.gd in Scripts/ folder
- [x] GameState.gd in Scripts/ folder  
- [x] Both autoloads configured in Project Settings
- [x] Verified test script runs without errors
- [x] Added game-specific events to EventBus
- [x] Customized GameState with your progress data
- [x] Read the documentation

## 🎮 You're Ready!

Start building your game using:
- `EventBus.your_event.emit()` to notify systems
- `EventBus.your_event.connect()` to listen for events
- `GameStateManager.set_setting()` to manage settings
- `GameStateManager.save_progress()` to save the game

Have fun! 🚀

