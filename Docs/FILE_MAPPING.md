# 📋 File Mapping Guide

Quick reference showing where each template file goes in your new project.

## 📂 Copy These Files

### Template Files → Your Project

```
FROM Template/                          TO Your New Project/
================================================================================

EventBus_Minimal.gd                 →   Scripts/EventBus.gd
GameState_Minimal.gd                →   Scripts/GameState.gd
EVENT_SYSTEM_MINIMAL.md             →   docs/EVENT_SYSTEM.md
README_TEMPLATE.md                  →   README.md (edit as needed)
.cursor/rules/quality-and-style.md  →   .cursor/rules/quality-and-style.md

SETUP_GUIDE.md                      →   (Reference only, optional to keep)
TEMPLATE_SUMMARY.md                 →   (Reference only)
FILE_MAPPING.md                     →   (Reference only - this file)
project_godot_snippet.txt           →   (Reference - add to project.godot)
```

## 🎯 Your New Project Structure

After copying, your project should look like:

```
YourNewGame/
│
├── project.godot                   # ← Add autoloads here (see snippet)
├── README.md                       # ← Your project's documentation
│
├── Scripts/                        # ← Core systems folder
│   ├── EventBus.gd                # ← Copied from EventBus_Minimal.gd
│   └── GameState.gd               # ← Copied from GameState_Minimal.gd
│
├── docs/                           # ← Documentation folder
│   └── EVENT_SYSTEM.md            # ← Copied from EVENT_SYSTEM_MINIMAL.md
│
└── .cursor/                        # ← Cursor AI rules folder
    └── rules/
        └── quality-and-style.md   # ← Copied as-is
```

## ⚙️ Configuration Required

### In Godot Editor: Project Settings → Autoload

Add these **in order**:

| Name | Path | Enabled |
|------|------|---------|
| `GameStateManager` | `res://Scripts/GameState.gd` | ✓ |
| `EventBus` | `res://Scripts/EventBus.gd` | ✓ |

**Or** manually add to `project.godot`:

```ini
[autoload]

GameStateManager="*res://Scripts/GameState.gd"
EventBus="*res://Scripts/EventBus.gd"
```

## ✏️ Customization Checklist

After copying files:

### EventBus.gd
- [ ] Add 2-5 events specific to your game type
- [ ] Document each signal with comments
- [ ] Remove commented sections you won't use

### GameState.gd
- [ ] Add your game-specific settings to `settings` dictionary
- [ ] Update `reset_settings_to_default()` with same settings
- [ ] Add progress tracking variables for your game
- [ ] Update `save_progress()` with your data
- [ ] Update `load_progress()` with your data

### docs/EVENT_SYSTEM.md
- [ ] Update examples to match your game
- [ ] Add documentation for your custom events
- [ ] Keep or remove optional patterns based on your needs

### README.md
- [ ] Update project name
- [ ] Update description
- [ ] Add your events to the quick reference
- [ ] Add game-specific instructions

## 🚫 Files You Don't Need to Copy

These are **reference only**:

- ❌ `SETUP_GUIDE.md` - Instructions for setup (read, don't copy)
- ❌ `TEMPLATE_SUMMARY.md` - Template overview (reference)
- ❌ `FILE_MAPPING.md` - This file (reference)
- ❌ `project_godot_snippet.txt` - Copy contents, not the file

## 🎮 Quick Copy Commands

### Windows (PowerShell from template directory):
```powershell
# Create folders
New-Item -ItemType Directory -Force -Path ..\NewGame\Scripts
New-Item -ItemType Directory -Force -Path ..\NewGame\docs
New-Item -ItemType Directory -Force -Path ..\NewGame\.cursor\rules

# Copy files
Copy-Item EventBus_Minimal.gd ..\NewGame\Scripts\EventBus.gd
Copy-Item GameState_Minimal.gd ..\NewGame\Scripts\GameState.gd
Copy-Item EVENT_SYSTEM_MINIMAL.md ..\NewGame\docs\EVENT_SYSTEM.md
Copy-Item README_TEMPLATE.md ..\NewGame\README.md
Copy-Item .cursor\rules\quality-and-style.md ..\NewGame\.cursor\rules\
```

### Linux/Mac (bash from template directory):
```bash
# Create folders
mkdir -p ../NewGame/Scripts
mkdir -p ../NewGame/docs
mkdir -p ../NewGame/.cursor/rules

# Copy files
cp EventBus_Minimal.gd ../NewGame/Scripts/EventBus.gd
cp GameState_Minimal.gd ../NewGame/Scripts/GameState.gd
cp EVENT_SYSTEM_MINIMAL.md ../NewGame/docs/EVENT_SYSTEM.md
cp README_TEMPLATE.md ../NewGame/README.md
cp .cursor/rules/quality-and-style.md ../NewGame/.cursor/rules/
```

## ✅ Verification

After copying and configuring, verify:

1. **Files exist**:
   - `Scripts/EventBus.gd` ✓
   - `Scripts/GameState.gd` ✓
   - `docs/EVENT_SYSTEM.md` ✓

2. **Autoloads configured**:
   - Open Project Settings → Autoload
   - See `GameStateManager` and `EventBus` listed

3. **Test script runs**:
   ```gdscript
   func _ready():
       if EventBus and GameStateManager:
           print("✓ Template installed successfully!")
       else:
           print("✗ Missing autoloads")
   ```

## 📝 Notes

- **Always rename** `_Minimal.gd` files to remove `_Minimal`
- **Don't forget** to configure autoloads in Project Settings
- **Order matters** - GameStateManager before EventBus
- **Customize immediately** - Add your game's events and settings

## 🎯 Next Steps

1. ✅ Copy all required files
2. ✅ Configure autoloads
3. ✅ Test with verification script
4. ✅ Add your game-specific events
5. ✅ Customize GameState for your data
6. 🎮 Start building your game!

---

**Need help?** Check `SETUP_GUIDE.md` for detailed instructions.

