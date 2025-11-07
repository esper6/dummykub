# Dummykub - Game Overview

## What We've Built

A fast-paced action game where a wizard beats up a training dummy for 60 seconds!

### Game Flow

1. **Intro Cutscene** (`Scenes/Intro.tscn`)
   - Three sentences animate in sequence
   - Each enters from bottom, holds, exits to top
   - Can skip with any button press
   - Automatically transitions to Main Menu

2. **Main Menu** (`Scenes/MainMenu.tscn`)
   - **PLAY** - Start new game
   - **CONTINUE** - Grayed out (no save yet)
   - **SETTINGS** - Adjust volume, fullscreen, vsync
   - **QUIT** - Exit game

3. **Game Scene** (`Scenes/Game.tscn`)
   - 60-second timer
   - Player wizard on the left
   - Training dummy on the right
   - Real-time combo and damage tracking

### Combat System

**Punch-Punch-Kick Combo:**
- Press **Square (Spacebar/Gamepad A)** three times
- Combo: Punch (10 dmg) → Punch (10 dmg) → Kick (25 dmg)
- Each hit triggers "hitstop" (freeze frames) for impact
- 0.5s window to continue combo
- After kick or timeout, combo resets

**Features:**
- Hitstop freeze frames on each hit
- Visual feedback (dummy shakes, player lunges)
- Combo counter and total damage display
- Game Over screen with retry/menu options

### Project Structure

```
Dummykub/
├── Scenes/
│   ├── Intro.tscn         # Opening cutscene
│   ├── MainMenu.tscn      # Main menu
│   ├── Settings.tscn      # Settings menu
│   ├── Game.tscn          # Main game scene
│   ├── Player.tscn        # Player wizard
│   └── Dummy.tscn         # Training dummy
│
├── Scripts/
│   ├── EventBus.gd        # Global event system
│   ├── GameState.gd       # Settings & save management
│   ├── Intro.gd           # Intro cutscene logic
│   ├── MainMenu.gd        # Menu navigation
│   ├── Settings.gd        # Settings management
│   ├── GameManager.gd     # Game timer & scoring
│   ├── Player.gd          # Player combat system
│   └── Dummy.gd           # Dummy reactions
│
└── project.godot          # Project configuration
```

### Controls

- **Spacebar / Gamepad Square (A button)** - Attack
- **Enter / Esc** - Menu navigation
- **Any key during intro** - Skip cutscene

### Current Visuals

All visuals are simple colored rectangles as placeholders:
- **Player**: Blue body, tan head/limbs, purple wizard hat
- **Dummy**: Brown post, tan body/head, brown base
- **Background**: Purple/dark gradient

## Next Steps: Creating Assets

Now that the game is functional, we can discuss:

1. **Sprites** - Replace colored rectangles with pixel art or drawn sprites
2. **Animations** - Create attack animations, hit reactions
3. **Effects** - Add particle effects for impacts, magic sparks
4. **Sound** - Hit sounds, music, UI feedback
5. **Polish** - Screen shake, better timing feedback, combo multipliers

The game is fully playable in Godot 4.5.1 right now!

