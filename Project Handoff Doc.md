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

### QTE Result Values (CRITICAL)
```gdscript
// AnimationBridge expects these EXACT values:
"crit" or "normal" → plays success_animation
"fail" → plays fail_animation
// NEVER use "success" - breaks the system!
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
1. Shop purchase implementation (currently placeholder)
2. Additional ability integrations using proven pattern
3. Memory system implementation (black-tinted animations)
4. Final balance tuning

---
*Key: Debug animations first, verify names exactly, test incrementally, follow proven patterns.*

● Perfect! Now Player2's hitstun animation will always appear at the fixed coordinates Vector2(207, 463). You can     
  easily edit that line 361 in AnimationBridge.gd to adjust the position to exactly where you want it.  (animationbridge.)