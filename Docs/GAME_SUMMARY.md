# Dummykub - Game Summary

## Overview

**Genre**: Action Platformer / DPS Test  
**Engine**: Godot 4.5  
**Objective**: Deal as much damage as possible to training dummies in 60 seconds

## Core Concept

Dummykub is a fast-paced arcade game where the player is a wizard who fights training dummies to maximize DPS (damage per second). The game focuses on:
- Tight, responsive combat with combo mechanics
- Skill-based movement with variable jump height
- Power-up collection for damage scaling
- Leveling system that unlocks elemental skills

## Gameplay Loop

1. **Start**: Player begins at level 1 with only melee attacks (no skills)
2. **Combat**: Fight dummies using punch-kick-uppercut combo or aerial pogo attacks
3. **Level Up**: Kill dummies to gain EXP → Level 2 triggers skill selection screen
4. **Skill Choice**: Choose ONE elemental skill: Thunderbolt, Fireball, or Ice Lance
5. **Power-ups**: Collect spawning power-ups to boost damage and abilities
6. **Timer**: Maximize damage dealt within 60 seconds

## Combat System

### Melee Combat (3-Hit Combo)
- **Punch** (LMB) → 10 damage
- **Kick** (LMB again) → 20 damage  
- **Uppercut** (LMB again) → 35 damage
- **Attack Delay**: 0.2s between each attack (scales with attack speed multiplier)
- **Cooldown**: 0.7s after completing full combo
- **Elemental Imbue**: With power-up, melee attacks deal elemental damage
- **Critical Hits**: 2x damage when crit chance procs (unlockable via level 3 ability)

### Aerial Combat
- **Pogo Attack** (Down + LMB in air) → 30 damage
- **Bounce**: Player bounces up after successful pogo hit
- **Cooldown**: Physics-based (resets when descending)
- **Animation**: Randomly cycles through 3 pogo animations

### Damage Numbers
- Floating damage numbers appear on every hit
- Color-coded by damage type (physical, fire, ice, lightning)
- Scale increases with damage amount

## Movement System

### Ground Movement
- **Horizontal**: Arrow keys/WASD at 400 units/sec
- **Character Flip**: Automatically faces movement direction

### Jump System (Advanced)
**First Jump (Ground Jump)**:
- **Variable Height**: Based on button hold duration
  - Tap (< 0.1s): 30% height
  - Short (< 0.2s): 55% height  
  - Medium (< 0.35s): 75% height
  - Full (≥ 0.35s): 100% height
- **Jump Velocity**: -700 units/sec

**Double Jump** (Unlocked via power-up):
- Fixed height (-550 units/sec)
- No variable height control
- Resets on landing

### Gravity Physics
- **Rising Gravity**: 2200 units/sec² (ascending)
- **Falling Gravity**: 2800 units/sec² (descending)
- Creates snappy, responsive arc: fast up → quick apex → fast down

## Skill System

### Skill Selection (Level 2)
Game pauses and presents 3 choices (pick one):

#### 1. Thunderbolt ⚡
- **Type**: Damage Over Time (DoT)
- **Behavior**: Attaches to target, ticks 10 times at 0.15s intervals
- **Damage**: Base 50 (split across 10 ticks)
- **Visual**: Blue electric bolt with spark particles
- **Unique**: Always ticks full duration regardless of distance traveled

#### 2. Fireball 🔥
- **Type**: Burst Damage
- **Behavior**: Explodes on contact, deals damage once
- **Damage**: Base 150 (3x normal projectile damage)
- **Visual**: Orange fireball with smoke/flame particles
- **Unique**: Big upfront damage, no DoT

#### 3. Ice Lance ❄️
- **Type**: Piercing Projectile
- **Behavior**: Passes through enemies, hits multiple targets
- **Damage**: Base 50 per enemy hit
- **Visual**: Cyan lance with star/ice crystal particles
- **Unique**: Can hit all dummies in a line

### Projectile System
- **Base Class**: `BaseProjectile.gd` - common logic for all projectiles
- **Speed**: 600 units/sec
- **Direction**: Aims toward mouse cursor in world space
- **Cooldown**: 1.0s between casts (scales with cooldown reduction)
- **Lifetime**: 1.0s (or until impact)

## Level 3+ Ability System

At level 3 and beyond, players can choose from passive "abilities" that enhance their combat power:

### Attack Speed (+50%)
- **Effect**: Reduces attack delay by 50% (from 0.2s to 0.13s)
- **Impact**: Faster punch-kick-uppercut combo execution
- **Stacking**: Multiplier stacks multiplicatively with itself
- **Visual**: Orange/red flash on acquisition

### Critical Hit Chance (+20%)
- **Effect**: Adds 20% chance for attacks to deal 2x damage
- **Impact**: Applies to ALL damage (melee and skills)
- **Stacking**: Additive stacking, caps at 100%
- **Visual**: Golden flash on acquisition, "CRITICAL HIT!" print on proc

### Cooldown Reduction (+25%)
- **Effect**: Reduces ALL cooldowns by 25%
- **Skill Cooldown**: 1.0s → 0.75s
- **Attack Combo Cooldown**: 0.7s → 0.525s
- **Stacking**: Additive stacking, caps at 80% reduction
- **Visual**: Blue flash on acquisition

## Power-Up System

Power-ups spawn every **10 seconds** at random locations. Multiple types exist:

### 1. Double Jump
- **Effect**: Unlocks double jump ability permanently
- **Spawn**: Only once per game round
- **Visual**: Green icon, bobbing animation

### 2. Damage Multiplier (1.3x - 2.1x)
- **Effect**: Permanently increases base damage multiplier
- **Weighting**: Lower multipliers more common (1.2x probability decrease per tier)
- **Visual**: Gold/orange star, color intensity shows tier
- **Stacking**: Multiplies with existing multiplier

### 3. Elemental Imbue
- **Effect**: Makes melee attacks deal elemental damage for 30 seconds
- **Element**: Based on chosen skill (lightning/fire/ice)
- **Visual**: Color-coded to element (cyan/orange/blue)
- **Buff Timer**: Displays visually on player

### 4. No Cooldown
- **Effect**: Removes ALL cooldowns for 15 seconds
- **Affects**: Skill cooldown (1s) + attack combo cooldown (0.7s)
- **Visual**: Bright green, fast spinning/pulsing
- **UI Integration**: Clears cooldown animations during buff

### Power-up Collection
- All power-ups have particle burst effect on collection
- Player gets visual color flash feedback
- Power-ups spawn at 7 different ground/platform locations

## Progression System

### Experience & Leveling
- **Start**: Level 1, 0 EXP
- **Level 2 Requirement**: 100 EXP
- **Level 3 Requirement**: 100 EXP (same per level)
- **Dummy EXP**: Each dummy grants 35 EXP (~3 dummies per level)
- **Level Up Effect**: Golden flash + scale pulse animation
- **Skill Unlock**: Level 2 pauses game and shows skill selection screen
- **Ability Unlock**: Level 3 pauses game and shows ability selection screen

### Health System (Dummies)
- **HP**: 500 per dummy
- **Health Bar**: Visible above dummy (red bar on gray background)
- **Death**: Type-specific death animation based on damage type:
  - Physical: Gray flash, fade out
  - Fire: Orange/red flash, burn effect
  - Ice: Blue flash, freeze/shatter effect
  - Lightning: Cyan/white flash, electrocution effect

### Dummy Spawning
- **Initial**: 1 dummy at game start
- **Spawn Rate**: Every 10 seconds OR when all dummies die (whichever first)
- **Max Active**: 3 dummies at once
- **Spawn Locations**: 5 different positions around arena

## Debug Features

### God Mode
- **Toggle**: Main menu checkbox "God Mode (100x dmg)"
- **Effect**: Multiplies ALL damage by 100x
- **Autoload**: Managed by `DebugSettings.gd` singleton
- **Purpose**: Quick testing without grinding

## UI System

### HUD Elements
- **Timer**: 60-second countdown (top center)
- **Level**: Current player level (top left)
- **EXP Bar**: Progress to next level with numerical display
- **Combo Counter**: Shows current hit combo
- **Damage Total**: Total damage dealt this round
- **Cooldown Icons**: Visual radial wipe for attack/skill cooldowns

### Cooldown Display
- **Style**: WoW-style radial wipe overlay
- **Icons**: Attack (fist) and Skill (lightning) icons
- **Shader**: Custom shader for clockwise wipe from 12 o'clock
- **Integration**: Connected to Player signals for real-time updates

### Pause Menu
- **Trigger**: ESC key
- **Process Mode**: Pauses game tree
- **Options**: Resume, Settings, Main Menu

## Technical Architecture

### Autoloads (Singletons)
1. **EventBus** (`Scripts/EventBus.gd`) - Global event system
2. **GameState** (`Scripts/GameState.gd`) - Persistent game state
3. **DebugSettings** (`Scripts/DebugSettings.gd`) - Debug toggles (God Mode)

### Scene Structure
- **MainMenu** → **Intro** → **Game** (main gameplay)
- **Game.tscn** contains: Player, Dummies, UIManager, GameManager, LevelUpScreen

### Key Scripts

#### Player (`Scripts/Player.gd`)
- Movement, jumping, combat input
- Combo state machine (IDLE, PUNCH, KICK, UPPERCUT, POGO)
- Skill casting system
- Damage multiplier tracking
- Buff timers (elemental imbue, no cooldown)
- Signals: `hit_landed`, `exp_gained`, `level_up`, `attack_cooldown_started`, `skill_cooldown_started`, `no_cooldown_activated`

#### GameManager (`Scripts/GameManager.gd`)
- Game timer (60s countdown)
- Dummy spawning logic
- Power-up spawning logic
- Score tracking (total damage, hits)
- EXP bar and level UI updates
- Connects Player signals to UI

#### Dummy (`Scripts/Dummy.gd`)
- Health management (500 HP)
- `take_damage(damage, position, animation, type)` method
- Death animations based on damage type
- EXP granting to player
- Health bar updates

#### BaseProjectile (`Scripts/BaseProjectile.gd`)
- Base class for all projectiles
- Common VFX setup (glow, particles, rotation)
- Movement physics
- Collision handling
- Inherited by: Thunderbolt, Fireball, IceLance

#### UIManager (`Scripts/UIManager.gd`)
- Manages HUD cooldown icons
- Connects to Player cooldown signals
- Updates visual cooldown overlays
- Handles No Cooldown buff UI clearing

### Collision Layers
- **Layer 1** (0x1): Environment (walls, floors)
- **Layer 2** (0x2): Player
- **Layer 4** (0x4): Enemies (dummies)
- **Layer 16** (0x16): Power-ups

### Particle System
All projectiles and power-ups use `GPUParticles2D` with `ParticleProcessMaterial`:
- Projectiles: Trailing particles matching element type
- Power-ups: Burst particles on collection
- Impact: Spark/explosion effects on hit

## Game Feel Details

### Hitstop
- **Duration**: 0.08s freeze on hit
- **Purpose**: Adds impact feel to attacks
- **Application**: Both player and enemy freeze briefly

### Screen Shake
- **Triggers**: Skill casting, powerful hits
- **Intensity**: 3.0 units
- **Duration**: 0.1s
- **Method**: Camera offset randomization

### Animation System
- **Player**: `AnimatedSprite2D` with walk, idle, attack animations
- **Flipping**: Scale.x manipulation (-1 for left, 1 for right)
- **Attack Offsets**: Visual root node offset for punch/kick impact

## Key Design Decisions

1. **Level 2 Skill Gate**: Player must earn their first skill, creates progression moment
2. **Level 3 Ability Gate**: Passive upgrades separate from active skills, creates build diversity
3. **Attack Delay System**: Small delay between combo hits makes attack speed upgrade meaningful
4. **Variable Jump Only on First Jump**: Maintains precision for complex movement
5. **Asymmetric Gravity**: Faster falling creates responsive, "game feel" physics
6. **DoT vs Burst vs Pierce**: Three distinct skill archetypes for different playstyles
7. **Damage Multiplier Stacking**: Allows exponential scaling for big DPS moments
8. **Critical Hit System**: Adds excitement and visual feedback, rewards crit chance investment
9. **No Cooldown Buff**: Enables "burst windows" for skill expression
10. **60 Second Timer**: Short rounds encourage replay and optimization

## Current State

- ✅ Core combat loop functional with attack delay system
- ✅ All 3 skills implemented and balanced
- ✅ Level 3 ability system (Attack Speed, Crit Chance, Cooldown Reduction)
- ✅ Critical hit system with 2x damage multiplier
- ✅ Power-up system complete (4 types)
- ✅ Variable jump height system
- ✅ Dummy spawning and death system
- ✅ EXP and leveling with skill/ability selection
- ✅ UI with cooldown tracking
- ✅ God Mode for testing
- ✅ Particle effects on all systems

## Files Reference

### Critical Gameplay Files
- `Scripts/Player.gd` - Player controller (~750 lines, includes ability system)
- `Scripts/GameManager.gd` - Game loop and spawning
- `Scripts/Dummy.gd` - Enemy logic
- `Scripts/BaseProjectile.gd` - Projectile base class
- `Scripts/Thunderbolt.gd` - DoT projectile
- `Scripts/Fireball.gd` - Burst projectile
- `Scripts/IceLance.gd` - Piercing projectile

### Power-up Files
- `Scripts/DoubleJumpPowerup.gd`
- `Scripts/DamageMultiplierPowerup.gd`
- `Scripts/ElementalImbue.gd`
- `Scripts/NoCooldownPowerup.gd`

### UI Files
- `Scripts/UIManager.gd` - HUD management
- `Scripts/CooldownIcon.gd` - Cooldown display widget
- `Scripts/LevelUpScreen.gd` - Level 2 skill selection screen
- `Scripts/AbilityUpScreen.gd` - Level 3+ ability selection screen
- `Scripts/DamageNumber.gd` - Floating damage text

### Core Scenes
- `Scenes/Game.tscn` - Main gameplay scene (includes Level 2 and 3 screens)
- `Scenes/Player.tscn` - Player character
- `Scenes/Dummy.tscn` - Training dummy with health bar
- `Scenes/Thunderbolt.tscn`, `Fireball.tscn`, `IceLance.tscn` - Projectiles
- `Scenes/AbilityUpScreen.tscn` - Level 3+ ability selection UI

## For AI Agents

When working on this codebase:
- Player uses signals extensively - check `Player.gd` signal list (includes `crit_hit` signal)
- GameManager is the central hub - connects Player to UI and game state
- All projectiles extend `BaseProjectile.gd` - add new skills by inheriting
- Power-ups follow standard pattern: collision detection → player method call → visual effect → `queue_free()`
- Damage flows through Dummy's `take_damage()` method - single point for all damage application
- Critical hits are rolled in `_on_weapon_hitbox_area_entered()` after damage calculation
- Attack delay system uses `attack_delay_timer` separate from `attack_cooldown` (combo cooldown)
- Level 2 shows skill selection (active abilities), Level 3+ shows ability selection (passive upgrades)
- Cooldown reduction and attack speed multipliers are applied when cooldowns start
- UI cooldowns are signal-driven - add new cooldowns by emitting from Player and handling in UIManager

