# VIFAE MVP Game Project - Complete Breakdown

## 🎮 **Project Overview**
**Engine**: Godot 4.4  
**Language**: GDScript  
**Genre**: Turn-based 2D RPG with QTE mechanics  
**MVP Goal**: Combat vs a single boss enemy  
**Status**: Advanced prototype with sophisticated QTE systems

---

## 🧭 **Project Architecture**

### **Core Structure**
```
vifae-mvp-cc/
├── scenes/           # Game scenes (.tscn files)
├── scripts/          # GDScript logic
│   ├── core/         # Global systems
│   ├── managers/     # Game state management
│   ├── player/       # Player characters
│   ├── enemy/        # Enemy behavior
│   └── ui/           # User interface
├── assets/           # All game assets
│   ├── animations/   # Sprite animations
│   ├── backgrounds/  # Arena backgrounds
│   ├── characters/   # Character sprites
│   ├── music/        # Background music
│   ├── sfx/          # Sound effects
│   ├── ui/           # UI elements
│   ├── objects/      # Game objects (bullets, etc.)
│   └── vfx/          # Visual effects
└── CLAUDE.md         # Development guidelines
```

### **Autoload Systems** (project.godot)
- **Global**: Core game state (`scripts/core/Global.gd`)
- **QTEManager**: QTE system handler (`scripts/managers/QTEManager.gd`)
- **VFXManager**: Visual effects (`scripts/managers/VFXManager.gd`)
- **CombatUI**: UI updates (`scripts/ui/CombatUI.gd`)
- **ScreenShake**: Camera effects (`scripts/ui/ScreenShake.gd`)

---

## ⚔️ **Combat System**

### **Turn-Based Core**
- **State Machine**: 16 distinct states in TurnManager
  - `BEGIN_TURN` → `ACTOR_READY` → `SHOW_MENU` → `QTE_ACTIVE` → `RESOLVE_ACTION` → `CHECK_END`
  - Victory/defeat conditions with proper overlay system
- **Turn Order**: Player1 → Player2 → Enemy (configurable via TurnOrderProvider)
- **Input Management**: Z/X/C split with input blocking to prevent carryover

### **Characters**
1. **Player1 - "Sword Spirit"** (50 HP)
   - **Basic Attack**: Ninja sequence with windup → QTE → attack → jumpback
   - **Abilities**: 2x Cut (dual QTE), Moonfall Slash (rapid-press), Spirit Wave, Uppercut
   - **Animation System**: Idle breathing + combat sequences

2. **Player2 - "Gun Girl"** (50 HP) 
   - **Basic Attack**: Ranged with muzzle flash and gun sounds
   - **Abilities**: Big Shot (sniper QTE), Scatter Shot (multi-target), Focus (damage buff)
   - **Animation System**: Sprite-swapping breathing (main ↔ idle2)
   - **Mechanics**: Focus stacking (2x, 4x, 6x damage multipliers)

3. **Enemy - "Boss"** (150 HP)
   - **AI Pattern**: Deterministic 5-attack rotation
   - **Attacks**: Multishot, Mirror Strike, Arc Slash, Lightning Surge, Phase Slam
   - **Animation**: Health-based idle states (50% HP triggers idle2)

---

## 🎯 **QTE System (1600+ lines)**

### **QTE Types**
1. **Basic Ring QTE**: Precision timing with growing fill ring
2. **Lightning Surge**: 3-window multi-tap sequence (parry timing)
3. **Phase Slam**: Hold & release with pressure bar
4. **Sniper QTE**: Moving crosshair precision
5. **Multishot**: Projectile deflection sequence
6. **Mirror Strike**: 6-button copy-cat sequence (W/A/S/D/Z/X)
7. **Rapid Press**: Button mashing (Moonfall Slash)

### **QTE Features**
- **Visual Feedback**: Custom ring textures, result flashes, X prompts
- **Audio Integration**: Timing-based sound effects per character
- **Precision Timing**: Graduated success (crit/normal/fail)
- **Anti-Carryover**: Input blocking between QTE phases

### **Advanced QTE Examples**

#### **Mirror Strike QTE** (Most Complex)
```
1. Generate 6-button sequence (W/A/S/D/Z/X)
2. Display sequence with button sprites
3. Player repeats sequence within 7 seconds
4. Real-time validation with press/release animations
5. Success = 0 damage, Failure = laser animation x2 + damage
```

#### **Lightning Surge QTE** (Multi-Window)
```
3 parry windows: [0.0-0.7s], [0.9-1.6s], [1.8-2.5s]
- Each window: growing ring + incoming.wav
- Late timing preferred (70-100% = perfect)
- Per-strike damage calculation (10 damage per missed strike)
```

---

## 🎨 **Animation Systems**

### **Player1 (Ninja)**
- **Idle**: Breathing animation via AnimationPlayer
- **Combat**: Dedicated CombatAnimations node
  - `attackwindup` → `attack` → `jumpback`
  - `2xwindup` → `2x` → `jumpback` (dual QTE)
  - `walk` → `uppercut` → `walk` (approach/retreat)

### **Player2 (Gun Girl)**
- **Idle**: Sprite swapping system (2-second breath cycle)
- **Combat**: Attack sprite windup + muzzle flash
- **Focus**: Buff animation with sprite cycling (buff1/buff2/buff3)

### **Enemy**
- **Idle**: AnimatedSprite2D with health-based states
- **Attacks**: Target-specific sprites (e-block vs Player1, e-block2 vs Player2)
- **Special**: Laser animation for Mirror Strike failures
- **Flinch**: Hit reaction sequence (flinch → flinch2 → idle)

---

## 🎵 **Audio System**

### **Music**
- **BGM**: `assets/music/bgm.mp3` (main battle theme)
- **Opener**: `assets/music/Opener.wav` (intro)
- **Game Over**: `assets/music/closer.wav` (defeat theme)

### **Sound Effects**
- **Combat**: attack.wav, crit.wav, miss.wav, parry.wav, parry2.wav
- **Guns**: gun1.wav (normal), gun2.wav (critical)
- **Special**: phaseslam1.wav (windup), phaseslam2.wav (impact)
- **UI**: menu.wav (navigation)
- **Warnings**: incoming.wav (enemy attack alerts)

### **Character-Specific Audio**
- **Player1**: parry.wav (crit), attack.wav (normal), miss.wav (fail)
- **Player2**: gun2.wav (crit), gun1.wav (normal), miss.wav (fail)
- **Enemy**: Phase Slam timing, Lightning Surge per-window audio

---

## 🖥️ **UI System**

### **Battle UI**
- **Action Menu**: Attack/Skills with keyboard navigation (W/S + Z/C)
- **Skills Menu**: Scrollable ability list per character
- **HP Bars**: Real-time updates for all characters
- **Turn Display**: Current actor indication
- **QTE Container**: Full-screen overlay system

### **Overlay Systems**
- **Pause Overlay**: ESC/P toggle with Resume/Quit
- **Result Overlay**: Victory/Defeat with Retry/Quit options
- **QTE Overlays**: Dynamic UI based on QTE type

### **Input Mapping**
```
Movement: W/A/S/D (menu navigation + Mirror Strike)
Actions: Z (confirm/attack), X (parry), C (cancel/dodge)
System: ESC/P (pause), M (music toggle)
```

---

## 📁 **Asset Organization**

### **Character Sprites**
- **Player1**: ninja.png, ninja_idle.png, ninja_attack.png, etc.
- **Player2**: p2.png, p2_idle.png, p2_idle2.png, p2-block.png, p2-dead.png
- **Enemy**: ENemy1.png, enemy_flinch1.png, enemy_flinch2.png

### **Animations**
- **Ninja Sequences**: ninja_attackwindup.png, ninja_attack.png, ninja_jumpback.png
- **Uppercut**: uppercut3.png, walkingp3.png
- **Enemy**: enemy-XT-idle1.png, enemy-XT-idle2.png, enemy-XT-laser.png

### **UI Elements**
- **QTE Assets**: qte_ring_empty.png, qte_ring_fill.png, qte_success.png, qte_fail.png
- **Button Prompts**: [key]_static.png, [key]_press.png for W/A/S/D/Z/X
- **Crosshairs**: crosshair_base.png, hitbox.png

### **Objects**
- **Projectiles**: bullet.png, bulletL.png, bulletR.png

---

## 🔧 **Technical Features**

### **Scene Management**
- **Main Scene**: BattleScene.tscn (complete battle arena)
- **Character Scenes**: Player1.tscn, Player2.tscn, Enemy.tscn
- **UI Scenes**: ResultOverlay.tscn, PauseOverlay.tscn, QTESniperBox.tscn

### **State Management**
- **Combat Reset**: Full state restoration on retry
- **Turn Order**: Configurable via TurnOrderProvider system
- **Input Blocking**: Prevents QTE input carryover
- **HP Synchronization**: Multiple HP display systems

### **Performance**
- **Asset Optimization**: Proper texture imports
- **Audio Management**: Centralized SFXPlayer system
- **Memory**: Proper node cleanup and tween management

---

## 🎪 **Game Flow**

### **Complete Battle Cycle**
```
1. Battle Start → Player1 Turn
2. Menu Navigation (Attack/Skills)
3. QTE Execution (ability-specific)
4. Damage Resolution + Animation
5. Turn Transition → Player2
6. Repeat for Player2
7. Enemy Turn (AI attack selection)
8. Enemy QTE (player defense)
9. Check Victory/Defeat Conditions
10. Loop or End Battle
```

### **Enemy Attack Pattern**
```
Turn 0: Multishot (projectile deflect QTE)
Turn 1: Mirror Strike (6-button sequence QTE)
Turn 2: Arc Slash (single parry QTE)
Turn 3: Lightning Surge (3-window multi-parry QTE)
Turn 4: Phase Slam (hold-release QTE)
[Repeats]
```
I fouind
---

## 🚀 **Current Development State**

### **Completed Systems**
✅ Full turn-based combat  
✅ 7 distinct QTE types  
✅ Character ability systems  
✅ Animation integration  
✅ Audio/visual feedback  
✅ UI/UX polish  
✅ Combat reset functionality  

### **MVP Goals Met**
✅ Playable 2v1 boss battle  
✅ Sophisticated QTE mechanics  
✅ Character progression (focus buffs)  
✅ Victory/defeat conditions  
✅ Audio/visual polish  

---

## 💡 **Key Design Decisions**

### **QTE Philosophy**
- **Graduated Success**: Crit/Normal/Fail instead of binary
- **Character Identity**: QTE types match character themes
- **Anti-Frustration**: Generous timing windows with clear visual feedback

### **Combat Balance**
- **Player HP**: 50 each (glass cannon approach)
- **Enemy HP**: 150 (endurance challenge)
- **Damage Scaling**: QTE performance directly affects damage

### **Technical Architecture**
- **Autoload Managers**: Centralized systems for reliability
- **Scene Composition**: Modular character/UI design
- **State Machine**: Clear combat flow with proper transitions

---

## 🎯 **Target Audience Notes**

This project demonstrates:
- **Advanced Godot 4 techniques**
- **Complex state management**
- **Polish and juice** (screen shake, audio timing, visual feedback)
- **Scalable architecture** (easy to add new characters/abilities)
- **Professional UI/UX** (pause system, result screens, input handling)

The codebase is **production-ready** for expansion into a full RPG, with systems designed for easy content addition and modification.

---

## 📝 **Development Context**

This represents a **sophisticated game development milestone** - far beyond a typical prototype. The QTE system alone (1600+ lines) rivals commercial implementations, and the character ability systems show deep understanding of game design principles.

**Perfect for showcasing**: Technical skills, game design understanding, and ability to create polished, playable experiences.