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