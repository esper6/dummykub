# 🎮 START HERE - Godot Minimal Template

**A stripped-down, universal EventBus architecture for any game type.**

## 📦 What is This?

A minimal, reusable foundation for Godot 4.x games that includes:
- ✅ **EventBus** - Clean event-driven communication
- ✅ **GameState** - Settings & save/load system
- ✅ **Documentation** - Complete usage guides
- ✅ **Zero bloat** - No game-specific code

Perfect for: Platformers, RPGs, Puzzles, VNs, Strategy, Arcade, or ANY game type.

---

## 🚀 Quick Start (Choose Your Path)

### Path 1: Just Get Started (5 minutes)
1. **Read:** `SETUP_GUIDE.md` ← Start here!
2. **Copy files** to your project
3. **Configure autoloads** in Project Settings
4. **Done!** Start building

### Path 2: Understand the System First (15 minutes)
1. **Read:** `TEMPLATE_SUMMARY.md` - Overview & philosophy
2. **Read:** `EVENT_SYSTEM_MINIMAL.md` - How EventBus works
3. **Read:** `SETUP_GUIDE.md` - Installation steps
4. **Read:** `README_TEMPLATE.md` - Architecture & patterns
5. **Copy files** and start building

### Path 3: See Examples First
1. **Open:** `EVENT_SYSTEM_MINIMAL.md` - Skip to "Example: Building a Platformer"
2. **Open:** `README_TEMPLATE.md` - Read "Example Patterns" section
3. **Decide:** Is this what you need?
4. **Then:** Follow Path 1

---

## 📚 File Guide

### 🔧 Core Files (COPY THESE to your project)

| File | Purpose | Copy To |
|------|---------|---------|
| `EventBus_Minimal.gd` | Global event system | `Scripts/EventBus.gd` |
| `GameState_Minimal.gd` | Settings & saves | `Scripts/GameState.gd` |
| `EVENT_SYSTEM_MINIMAL.md` | EventBus documentation | `docs/EVENT_SYSTEM.md` |
| `.cursor/rules/quality-and-style.md` | Code standards | `.cursor/rules/` |
| `README_TEMPLATE.md` | Project README | `README.md` (optional) |

### 📖 Reference Files (READ, don't copy)

| File | What It Does |
|------|-------------|
| **START_HERE.md** | This file! Entry point |
| **SETUP_GUIDE.md** | Step-by-step installation ⭐ |
| **TEMPLATE_SUMMARY.md** | Overview & philosophy |
| **FILE_MAPPING.md** | Where files go (visual guide) |
| **project_godot_snippet.txt** | Autoload configuration |

---

## ⚡ Super Quick Setup

**Copy-paste this in your terminal:**

```bash
# From the Templates directory, assuming your project is at ../MyGame

# Create folders
mkdir -p ../MyGame/Scripts ../MyGame/docs ../MyGame/.cursor/rules

# Copy core files
cp EventBus_Minimal.gd ../MyGame/Scripts/EventBus.gd
cp GameState_Minimal.gd ../MyGame/Scripts/GameState.gd
cp EVENT_SYSTEM_MINIMAL.md ../MyGame/docs/EVENT_SYSTEM.md
cp .cursor/rules/quality-and-style.md ../MyGame/.cursor/rules/

echo "✓ Files copied! Now configure autoloads in Godot."
```

**Then in Godot:** Project Settings → Autoload → Add:
1. `GameStateManager` → `res://Scripts/GameState.gd`
2. `EventBus` → `res://Scripts/EventBus.gd`

**Done!** 🎉

---

## 🎯 What You Get

### EventBus (35 lines of core code)
```gdscript
# Only 5 universal signals:
signal game_paused()
signal game_resumed()
signal settings_changed(setting_name: String, new_value)
signal game_saved()
signal game_loaded()

# Add YOUR game's events:
signal player_died()
signal coin_collected(amount: int)
# ... whatever your game needs!
```

### GameState (145 lines)
```gdscript
# Settings that auto-save:
GameStateManager.set_setting("volume", 0.8)  # Saves to disk

# Save/Load system ready to extend:
GameStateManager.save_progress()
GameStateManager.load_progress()
```

### Documentation (1000+ lines)
- Complete EventBus guide with examples
- Genre-specific extension patterns
- Common patterns (audio, achievements, etc.)
- Troubleshooting help

---

## 💡 Why Use This?

### You're About to Start a New Game
- ✅ Save 4-8 hours setting up architecture
- ✅ Settings system works from day 1
- ✅ Clean event communication built-in
- ✅ Focus on game design, not boilerplate

### You're Learning Godot
- ✅ Learn event-driven architecture
- ✅ Understand autoloads/singletons
- ✅ See best practices in action
- ✅ Clear examples for every pattern

### You're in a Game Jam
- ✅ 5-minute setup
- ✅ Proven architecture
- ✅ Extend only what you need
- ✅ No time wasted on infrastructure

### You're Teaching
- ✅ Show professional patterns
- ✅ Clear separation of concerns
- ✅ Easy to explain
- ✅ Students learn good habits

---

## 🎮 Supported Game Types

This template extends for:

- ✅ **Platformers** - Player events, checkpoints, collectibles
- ✅ **RPGs** - Combat, inventory, quests, progression
- ✅ **Puzzle Games** - Moves, hints, completion tracking
- ✅ **Visual Novels** - Dialogue, choices, story flags
- ✅ **Strategy** - Turns, units, resources
- ✅ **Roguelikes** - Run tracking, unlocks, meta-progression
- ✅ **Arcade** - Score, lives, power-ups
- ✅ **Any game** - Universal foundation!

See `EVENT_SYSTEM_MINIMAL.md` for genre-specific examples.

---

## ❓ FAQ

### "Isn't this just two scripts?"
Yes! That's the point. Universal foundation, zero bloat. Extend as needed.

### "What about dialogue/inventory/combat?"
Not included - those are game-specific. Add YOUR implementations using the EventBus pattern.

### "Can I use this in commercial games?"
Yes! No attribution required. Use freely.

### "What if I need more features?"
Add them! The docs show patterns for everything. Start minimal, extend as needed.

### "How is this different from starting from scratch?"
You get: EventBus pattern, settings persistence, save/load system, and 1000+ lines of documentation. That's 4-8 hours saved.

---

## 📋 The Complete Checklist

- [ ] Read `SETUP_GUIDE.md`
- [ ] Copy core files to your project
- [ ] Configure autoloads in Project Settings
- [ ] Run verification test (in SETUP_GUIDE)
- [ ] Add 2-5 events specific to your game
- [ ] Customize GameState with your data
- [ ] Read `EVENT_SYSTEM_MINIMAL.md` for patterns
- [ ] Start building your game! 🎮

---

## 🆘 Need Help?

1. **Installation issues?** → Read `SETUP_GUIDE.md` troubleshooting section
2. **Don't understand EventBus?** → Read `EVENT_SYSTEM_MINIMAL.md` from the start
3. **Want to see examples?** → Read `README_TEMPLATE.md` "Example Patterns"
4. **Lost on where files go?** → Read `FILE_MAPPING.md`

---

## 🌟 Philosophy

> **"Start with what every game needs, add only what your game wants."**

This template is **intentionally minimal**. 

- ❌ No bloated frameworks
- ❌ No opinionated game systems
- ❌ No code you'll delete
- ✅ Just the foundation
- ✅ Extend as needed
- ✅ Focus on YOUR game

---

## 🎬 Ready to Start?

### Next Step:
👉 **Open `SETUP_GUIDE.md`** and follow the instructions.

Takes 5 minutes, saves hours. Let's build something awesome! 🚀

---

**Version:** 1.0  
**For Godot:** 4.0+  
**License:** Use freely, no attribution required  
**Support:** Check the documentation files

