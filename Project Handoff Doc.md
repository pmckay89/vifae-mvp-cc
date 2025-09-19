# Claude Development Handoff - Vifae MVP

**Engine**: Godot 4.4 | **Language**: GDScript | **Date**: January 15, 2025

## 🎮 GAME CONTEXT
Turn-based 2D RPG with QTE mechanics. 5-battle campaign with progressive shop system. Two players (ninja + gunner) vs scaling enemies.

## 🏗️ CORE ARCHITECTURE

### Animation System (CRITICAL - Read First)
```
TurnManager → AnimationBridge → "testing animations.tscn" → Visual Result
```

**TWO ANIMATION SYSTEMS - Don't Confuse Them:**
- **AnimatedSprite2D**: Sprite frame sequences (`"2x cut finish"`)
- **AnimationPlayer**: Scene animations (`"2x_finish"`)
- **AnimationBridge uses AnimationPlayer names ONLY**

### Key File Locations
```
scripts/managers/AnimationBridge.gd    # Central animation controller
scripts/managers/ProgressManager.gd    # Battle progression & enemy scaling
scenes/ui/ShopOverlay.gd               # Progressive shop system
testing animations.tscn                # ALL animations live here
```

## 🚨 ANIMATION DEBUGGING (Common Failure Points)

### MISTAKE #1: Wrong Animation Names
```gdscript
// ❌ WRONG - Uses AnimatedSprite2D name
AnimationBridge.play_windup_animation("BE_Test1_Windup")

// ✅ CORRECT - Always verify AnimationPlayer names first
print("Available: ", animation_player.get_animation_list())
```

### MISTAKE #2: Missing AnimationPlayer Tracks
**Symptoms**: Wrong player sprites appear, animations don't play
**Solution**: After adding sprite frames, create AnimationPlayer tracks to control them

### MISTAKE #3: Animation Loop Conflicts (CRITICAL FIX)
**Symptoms**: Windup animations loop during QTE instead of pausing
**Root Cause**: TWO animation systems conflict:
- AnimationPlayer: Has `loop_mode = 0` (correct - plays once, pauses)
- AnimatedSprite2D: Has `"loop": true` (wrong - keeps cycling frames)

**PERMANENT SOLUTION IMPLEMENTED**:
```
WINDUP ANIMATIONS MUST HAVE: "loop": false in SpriteFrames
✅ Fixed: ninja_ww_windup, 2x cut windup, BE_Test1_Windup
```

**Pattern**: All windup sprite animations need `"loop": false` to work with AnimationBridge

### Pre-Integration Checklist
1. Sprite frames exist in AnimatedSprite2D ✓
2. AnimationPlayer tracks created ✓
3. Test `animation_player.play("name")` independently ✓
4. Verify exact names with `get_animation_list()` ✓

## 🏪 SHOP SYSTEM (Current State)

### Progressive Unlock Logic
```gdscript
// After completing battle X, show these tabs:
Battle 1: Items only (1-2 coins)
Battle 2: Items + Upgrades (3-6 coins)
Battle 3+: Items + Upgrades + Abilities (3 coins)
```

### Flow Pattern
```
Battle → Victory → "Continue" → Shop → "Leave Shop" → ProgressManager.advance_position() → Next Battle
```

## 🎯 ABILITY INTEGRATION PATTERN (Proven)

```gdscript
func execute_ability_sequence(target):
    # 1. Spawn via AnimationBridge
    var instance = AnimationBridge.spawn_ability_animation("ability_name", Vector2.ZERO, self)

    # 2. Play windup
    AnimationBridge.play_windup_animation("ability_name")
    await AnimationBridge.animation_ready_for_qte

    # 3. QTE
    var qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z!", self)

    # 4. IMMEDIATE damage application (no delays!)
    _apply_damage_immediate(qte_result, target)

    # 5. Result animation (use exact QTE result: "crit"/"normal"/"fail")
    AnimationBridge.play_result_animation("ability_name", qte_result)
    await AnimationBridge.animation_sequence_complete

    # 6. Return for TurnManager
    return {"damage": damage_dealt, "qte_results": [qte_result], "success": damage > 0}
```

## 🐛 DEBUGGING COMMANDS
```gdscript
# Animation system verification
print("AnimatedSprite2D: ", sprite.sprite_frames.get_animation_names())
print("AnimationPlayer: ", animation_player.get_animation_list())

# Resolve system (Q/A for P1, E/D for P2)
ResolveManager.add_resolve("Player1", 1)  # Q key
ResolveManager.remove_resolve("Player1", 1)  # A key
```

## 🎨 USER COMMUNICATION PATTERNS

### Warning Signals
- **"you're not listening"** = Misunderstood which player/sprite should be affected
- **"user error as usual"** = Missing AnimationPlayer tracks (user needs to create them manually)
- **Animation name corrections** = Exact spelling/capitalization matters

### User Preferences
- Test one thing at a time, then roll out
- Incremental changes over big rewrites
- Placeholder-friendly systems (missing animations → use basic_attack)
- Direct questions: "what exact animation names are we using?"

## 🏆 CAMPAIGN PROGRESSION

### Battle Scaling (ProgressManager)
```gdscript
Battle 1: 1.0x stats (Tutorial Boss)
Battle 2: 1.5x stats (Shadow Beast)
Battle 3: 2.0x stats (Elite Guardian)
Battle 4: 2.5x stats (Ancient Warden)
Battle 5: 3.0x stats (Final Boss)
```

### Shop Randomization
- Items: 2-3 random per visit
- Upgrades: 2-3 random per visit
- Abilities: 4 random (2 shared, 1 P1, 1 P2) per visit

## 🔧 CRITICAL FUNCTIONS

### AnimationBridge Registration
```gdscript
"ability_name": {
    "scene_path": "res://testing animations.tscn",
    "windup_animation": "exact_animationplayer_name",
    "success_animation": "exact_animationplayer_name",
    "modulate_color": Color.BLACK  // Optional tinting
}
```

### QTE Result Values (EXACT)
- Use: `"crit"`, `"normal"`, `"fail"`
- Never: `"success"` (breaks AnimationBridge logic)

## 🚀 CURRENT STATE
- ✅ 5-battle campaign with scaling
- ✅ Progressive shop system
- ✅ Modular ability architecture
- ✅ Ghost Attack with black silhouette
- ✅ Streamlined UI (no quit buttons, "Continue" flow)
- ✅ Multishot hitstun animations with perfect positioning
- ✅ Mirror Strike QTE improvements (now first attack in cycle)
- ✅ Player2 sprite cleanup (legacy idle2 sprite removed)

## 🎪 PROVEN ABILITY IMPLEMENTATIONS

### Player Ability Lists
```gdscript
// Player 1 (Ninja/Sword) - 9 abilities
["basic_attack", "2x_cut", "moonfall_slash", "spirit_wave", "whirlwind", "ghost_attack",
 "poison", "burn_strike", "shield_boost", "mark_target"]

// Player 2 (Gunner/Ranged) - 8 abilities
["basic_attack", "big_shot", "scatter_shot", "focus", "grenade", "bullet_rain",
 "freezing_shot", "armor_piercing", "bleeding_shot"]

// Shared Pool (Status Effects)
["poison", "burn_strike", "shield_boost", "mark_target", "freezing_shot",
 "armor_piercing", "bleeding_shot", "berserker_rage", "healing_touch",
 "curse_strike", "time_shift", "energy_barrier"]
```

### Status Effect System (Working Examples)
```gdscript
// Immediate damage + status application pattern
func execute_status_ability(target):
    # Standard AnimationBridge flow...

    # IMMEDIATE damage application (no delays!)
    var damage = calculate_damage(qte_result)
    target.take_damage(damage)

    # Apply status effect
    if qte_result in ["normal", "crit"]:
        match ability_name:
            "freezing_shot": StatusManager.apply_status(target, "frozen", 1)
            "bleeding_shot": StatusManager.apply_status(target, "bleed", 3)
            "armor_piercing": StatusManager.apply_status(target, "armor_down", 2)
```

### Special Implementations

#### Ghost Attack (Black Silhouette)
```gdscript
// AnimationBridge registration with tinting
"ghost_attack": {
    "scene_path": "res://testing animations.tscn",
    "windup_animation": "BE_Test1_Windup",
    "success_animation": "BE_Test1_Finish",
    "modulate_color": Color.BLACK  // Black silhouette effect
}
```

#### Multishot QTE (Randomized Timing)
```gdscript
// Enhanced multishot with random intervals
for i in range(projectile_count):
    var random_delay = randf_range(0.2, 0.8)
    await get_tree().create_timer(random_delay).timeout
    # Launch projectile at 850 pixels/second
```

#### Big Shot Targeting
```gdscript
// Red crosshair positioned over enemy horizontally
crosshair_position = Vector2(enemy.global_position.x, screen_center.y)
```

## 🎨 GODOT 4.4 SPECIFIC PATTERNS

### Critical Syntax Rules
```gdscript
// ✅ ALWAYS use Godot 4+ syntax
@onready var node := $NodePath
@export var property: int = 5
var tween = create_tween()

// ❌ NEVER use Godot 3 patterns
onready var node = $NodePath  # Old syntax
export var property = 5       # Old syntax
yield(timer, "timeout")       # Use await instead
```

### Animation Timing Fixes
```gdscript
// Prevent animation lingering after completion
await animation_player.animation_finished
animation_player.pause()  // Critical for clean stops
```

## 🔊 AUDIO SYSTEM
```gdscript
// Working sound file paths
"res://assets/sfx/attack.wav"     // Basic attacks
"res://assets/sfx/bullet.wav"     // Gunner abilities
// Note: blade_hit.wav doesn't exist - use attack.wav
```

## 🎮 QTE MECHANICS

### Enemy Attack Cycle (Updated)
```gdscript
Turn 0: Mirror Strike (6-button sequence QTE)
Turn 1: Multishot (projectile deflect QTE)
Turn 2: Arc Slash (single parry QTE)
Turn 3: Lightning Surge (3-window multi-parry QTE)
Turn 4: Phase Slam (hold-release QTE)
[Repeats]
```

### QTE Result Values (CRITICAL)
```gdscript
// AnimationBridge expects these EXACT values:
"crit" or "normal" → plays success_animation
"fail" → plays fail_animation
// NEVER use "success" - breaks the system!
```

### Mirror Strike Details
```gdscript
// QTE: 6-button sequence (Z/X/W/A/D/S) within 7 seconds
// Success: 0 damage, +1 resolve
// Failure: 30 damage + laser animation + laserimpact.wav (0.5s delay)
// Includes hitstun animations for both players
```

### Turn Flow Integration
```gdscript
// Modular abilities must return proper damage info
return {
    "damage": damage_dealt,
    "qte_results": [qte_result],
    "success": damage_dealt > 0,
    "handled_damage": true  // Prevents duplicate damage
}
```

## 🏪 MEMORY SYSTEM (Esper/Summon Concept)
```gdscript
// Reuse existing animations with black tint for "shadow" abilities
var memory_abilities = {
    "shadow_strike": {
        "animation": "basic_attack_p1",  // Reuses Player1 attack
        "tint": Color.BLACK,             // Complete black silhouette
        "category": "memory",
        "resolve_cost": 4                // Higher cost than regular skills
    }
}
```

## 🔧 UI SYSTEM NOTES

### FF-Style UI Paths
```gdscript
// Resolve system paths (fixed for new UI)
var resolve_label_path = "/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/" +
                        player_name + "Row/" + player_name + "Info/" + player_name +
                        "Header/" + player_name + "ResolveCount"
```

### Turn Menu Structure
```
Attack → Skills → Memory → Items
```

## 🎯 NEXT PRIORITIES
1. ✅ ~~Shop purchase implementation~~ **COMPLETED** - Full 7-item system with discovery mechanics
2. Per-player upgrade system implementation (37 upgrades designed, only 1 functional)
3. Character stats/upgrade display system (prevent information overload during combat)
4. Additional ability integrations using proven pattern
5. Memory system implementation (black-tinted animations)
6. Final balance tuning

---

# Recent Progress Updates

## January 15, 2025 - Complete Item System & Shop Integration

### ✅ **MAJOR COMPLETIONS**

**Complete 7-Item System Implemented:**
- HP Potion (50 HP instant) - 1 coin
- Resolve Potion (3 Resolve) - 1 coin
- Rage Potion (rage status: +100% damage, +25% incoming, 3 turns) - 2 coins
- Speed Boost (haste status: act twice per turn, 2 turns) - 2 coins
- Pain Killer (damage immunity for 1 hit) - 2 coins
- Bandages (regeneration: 15 HP/turn for 3 turns) - 1 coin
- Phoenix Feather (revive with 50% HP on death) - 2 coins

**Discovery-Based Progression:**
- Items hidden until purchased from shop (no more free starting items)
- Items button non-responsive when no items owned
- Only discovered items appear in inventory menu
- Creates "what else exists?" motivation to visit shops

**Shop Purchase System:**
- Full purchase logic implemented with coin deduction
- 1 purchase per item per shop visit limit
- Visual "SOLD" feedback for purchased items
- Tab selection preserved after purchases (no more forced tab switching)

**Dynamic Items Menu:**
- Scrolling system (4 items visible, handles any count)
- Positioned same as Skills menu (no screen overflow)
- Filters to show only owned items
- Proper selection mapping (fixed crash bug)

### 🔧 **CRITICAL BUG FIXES**

**Parser Errors (Variable Conflicts):**
- Multiple `current_player_name` declarations in same scope
- Conflicting `items` vs `items_list` arrays
- **Lesson**: Check for variable name conflicts in function scope

**Item Selection Mapping Bug:**
- Display logic used filtered array (only items with count > 0)
- Selection logic used full hardcoded array (all 7 items)
- Result: Player selects "Pain Killer" but system uses wrong item
- **Fix**: Both display AND selection now use same filtered array

**Regeneration Stacking Crash:**
- `max()` function called on Object types (Player references) instead of numbers
- Crash: `max(Player_object, 0)` when applying bandages with existing regen
- **Fix**: Type checking - only use `max()` on numeric values, exclude "target"/"caster"

**Pain Killer Barrier Persistence:**
- Used regular "barrier" effect which has duration management
- Created separate "pain_killer" effect to avoid conflicts with ability barriers
- **Lesson**: Don't reuse complex status effects - create specific ones

### 🏗️ **DISCOVERED ASSETS**

**Massive Upgrade Library Found (37 total!):**
- ShopOverlay.gd: 4 upgrades (currently implemented)
- UpgradeOverlay.tscn: 33 additional upgrades (designed but not functional)
- Comprehensive upgrade system waiting for implementation
- **Decision**: Per-player upgrades (not party-wide) for strategic depth

### 📚 **LESSONS LEARNED (Time-Savers)**

**1. Variable Scope Conflicts:**
- Always check for existing variable names in function scope
- Use unique names like `items_list` vs `items` when needed
- GDScript parser errors are specific - read them carefully

**2. Array Consistency:**
- When filtering arrays for display, ensure selection logic uses SAME filtered array
- Don't mix filtered display with hardcoded selection indices
- Test edge cases (empty arrays, single items)

**3. Status Effect Isolation:**
- Don't reuse complex status effects for simple items
- Create specific effect types to avoid system conflicts
- "barrier" vs "pain_killer" - different behaviors need different types

**4. Type Safety in Utility Functions:**
- `max()`, `min()` require same types
- Check `typeof()` before using math functions on dictionary values
- Objects vs numbers cause silent crashes

**5. UI State Preservation:**
- Tab containers reset when content refreshed
- Save/restore UI state around major updates
- User experience trumps code simplicity

**6. Asset Discovery:**
- Use agents for comprehensive codebase searches
- Design documents may exist in scene files, not just .gd files
- Look beyond obvious locations for complete feature sets

### 🎮 **CURRENT GAME STATE**
- **Items**: Fully functional 7-item system with discovery progression
- **Shop**: Complete purchase system with limits and visual feedback
- **Combat**: All existing abilities work with new item effects
- **Progression**: Battle → Shop → Items discovered → Strategic choices
- **Upgrades**: 37 designed (only iron_will functional) - major expansion opportunity

## 🎬 HITSTUN ANIMATION SYSTEM

### Current Positioning (AnimationBridge.gd)
```gdscript
// Player1 hitstun positioning and scaling
hero_root.position = Vector2(35, 330)
hero_root.scale = Vector2(1.25, 1.25)  // 25% larger

// Player2 hitstun positioning and scaling
hero_root.position = Vector2(40, 430)
hero_root.scale = Vector2(1.20, 1.20)  // 20% larger
```

### Animation Triggers
```gdscript
// Multishot projectile hits
if target_player.name == "Player1":
    animation_bridge.play_hitstun_animation("ninja_hitstun", "Player1")
elif target_player.name == "Player2":
    animation_bridge.play_hitstun_animation("hitstun", "Player2")

// Mirror Strike failures (same positioning)
```

### Sprite Management
- **Player1**: Uses "idle" sprite node
- **Player2**: Uses "IdleAnimatedSprite" and "Sprite2D" nodes
- Legacy "idle2" sprite completely removed from Player2

---
*Key: Debug animations first, verify names exactly, test incrementally, follow proven patterns.*