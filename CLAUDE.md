# Claude Project Context: Solo Game MVP (Godot 4.4)

## 🧱 ENGINE & LANGUAGE
- Engine: **Godot 4.4**
- Language: **GDScript**
- File extensions: `.gd`, `.tscn`, `.tres`
- All code must use **Godot 4+ syntax** and APIs. Do NOT use Godot 3 patterns (e.g., `yield()` or old signal syntax).
- Use `@onready`, `@export`, `create_tween()`, and other G4-native features.
- Assume GDScript 2.0 unless otherwise noted.

## 🧭 PROJECT STRUCTURE
- Scenes: `res://scenes/`
- Scripts: `res://scripts/`
- UI: `res://scenes/ui/`
- Assets: `res://assets/` (with subfolders like `characters`, `music`, `sfx`)
- Character animations are sprite-based. Use `AnimatedSprite2D` or `AnimationPlayer` only.

## ⚔️ GAME TYPE
- Turn-based 2D RPG with QTE mechanics
- MVP goal: Combat vs a single boss enemy
- Characters are controlled via UI or single keypress (Z/X/C input split)

## ✅ WHEN WRITING CODE:
- **Only write code compatible with Godot 4.4**
- **NEVER use Godot 3 syntax**
- **NEVER assume plugins or assets exist unless I tell you**
- Only add **small, focused features**—preserve existing working behavior
- DO NOT generate full files unless explicitly told—assume I'm working incrementally

## 🧠 WHEN UNCERTAIN:
- Ask me before generating code that modifies multiple systems

## Development Guidelines

### Godot Version
- **Target Version**: Godot 4.x
- Always ensure code compatibility with Godot 4 API
- Key differences from Godot 3:
  - `get()` method only accepts one parameter - use `obj.get("property") if "property" in obj else default_value` instead of `obj.get("property", default_value)`
  - Updated node path syntax and method names
  - New typing system requirements

### Code Style
- Follow existing project conventions
- Maintain consistency with surrounding code


  ## Animation System
  - Use AnimationBridge for complex animations
  - All combat animations are in "testing animations.tscn"
  - Basic attacks use: windup → QTE → result animation → cleanup

  ## Before Executing 
  - Ask me clarifying questions to ensure we get it right first try. 


  ## Golden Rule
  The Golden Rule: LOOK → PROPOSE → CONFIRM → EXECUTE
1. LOOK FIRST, ALWAYS

"I should also check your TurnManager.gd to understand how this connects"
Never assume the user knows the project well, or anything about code - he doesn't.

2. PROPOSE CHANGES CLEARLY

Show what I found in the current code
Outline specific changes I'm proposing with clear reasoning
Identify which file(s) need updates
Consider scalability: "This will work for your MVP and scale when you add more enemies"
One focused proposal - don't overwhelm with multiple options

3. CONFIRM BEFORE PROCEEDING

Wait for Phil's approval: "Does this approach sound good? Any questions before I implement it?"
Answer any clarifying questions Phil has about the proposal
Get explicit go-ahead: "Proceed with the update" or similar confirmation


5. KEY PRINCIPLES

Phil knows nothing about coding - explain technical decisions simply
MVP focus - prioritize working game over perfection
Modular when it matters - build reusable systems if they'll be used 3+ times
One task at a time - complete each change fully before moving to the next
Step-by-step confirmation - check that Phil completed each step

6. FORBIDDEN ACTIONS

❌ Never update code without explicit approval
❌ Never assume current code state
❌ Never give 5+ questions at once (Phil will derail)
❌ Never implement without showing the plan first


7. SUCCESS PATTERN
✅ "Let me check your current EnemyAI.gd..."
✅ [Fetch current code]
✅ "I propose adding smart target selection that prioritizes low-HP players. This means updating the target selection logic in lines 20-25. Sound good?"
✅ [Wait for approval]
✅ "Proceeding with the update..."
✅ [One-shot perfect implementation]
RESULT: working code in 1-2 exchanges instead of debugging loops.