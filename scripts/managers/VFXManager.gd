extends Node

# Enhanced VFX system with color tints and intensity scaling
enum EffectType {
	NORMAL,
	POISON,
	BURN,
	ICE,
	LIGHTNING,
	CRITICAL,
	ULTIMATE
}

# Call this to play a hit reaction on a target node
func play_hit_effects(target_node: Node):
	play_enhanced_hit_effects(target_node, 0, EffectType.NORMAL)

# Enhanced version with color tints and intensity options
func play_enhanced_hit_effects(target_node: Node, damage: int, effect_type: EffectType = EffectType.NORMAL):
	if target_node == null:
		print("⚠️ Attempted to hit a null target")
		return
	
	# Get camera for shake effects
	var cam = get_node_or_null("/root/BattleScene/BattleCamera")
	
	# Scale shake intensity based on effect type
	if cam and cam.has_method("shake"):
		match effect_type:
			EffectType.CRITICAL:
				cam.shake(0.5, 8.0)    # Longer, more intense
			EffectType.ULTIMATE:
				cam.shake(0.8, 12.0)   # Maximum drama
			EffectType.ICE:
				cam.shake(0.4, 6.0)    # Moderate intensity for ice
			EffectType.LIGHTNING:
				cam.shake(0.6, 10.0)   # Sharp, intense shake
			_:
				cam.shake(0.3, 4.0)    # Standard intensity
	
	# Skip flash effects for now - they look amateur and have positioning issues
	# Focus on just enhanced camera shake for different effect types

	# Play appropriate hit reaction based on target type
	if target_node.name.begins_with("Player") and target_node.has_method("show_block_animation"):
		# Players have block animations
		target_node.show_block_animation()
	elif target_node.name == "Enemy" and target_node.has_method("show_flinch_animation"):
		# Enemy uses flinch animation as hit reaction (already called in take_damage)
		pass

# Flash functions removed - were causing positioning issues and looked amateur

# Status effect visual amplification with mini-zoom and slowmo
func play_status_effect_vfx(target_node: Node, effect_type: String, tier: int = 1):
	if target_node == null:
		return
	
	var effect_enum = _string_to_effect_type(effect_type)
	
	match tier:
		1: # Basic status effect
			play_enhanced_hit_effects(target_node, 0, effect_enum)
		2: # Enhanced status effect with mini-zoom
			play_enhanced_hit_effects(target_node, 0, effect_enum)
			_camera_mini_zoom(target_node, 1.1, 0.3)
		3: # Ultimate status effect with dramatic zoom + slowmo
			play_enhanced_hit_effects(target_node, 0, EffectType.ULTIMATE)
			_camera_dramatic_zoom(target_node, 1.3, 0.5)
			_brief_slowmo(0.15, 0.3)  # 0.3x speed for 0.15 seconds

# Helper function to convert status effect strings to enum
func _string_to_effect_type(effect_type: String) -> EffectType:
	match effect_type:
		"poison", "bleed": return EffectType.POISON
		"burn": return EffectType.BURN
		"frozen": return EffectType.ICE
		"shock", "lightning": return EffectType.LIGHTNING
		_: return EffectType.NORMAL

# Camera mini-zoom for status effects
func _camera_mini_zoom(target_node: Node, zoom_scale: float, duration: float):
	var cam = get_node_or_null("/root/BattleScene/BattleCamera")
	if cam and cam.has_method("zoom_to_target"):
		cam.zoom_to_target(target_node, zoom_scale, duration * 0.6)
		await get_tree().create_timer(duration * 0.4).timeout
		if cam.has_method("zoom_to_original"):
			cam.zoom_to_original(duration * 0.4)

# Dramatic camera zoom for ultimate effects
func _camera_dramatic_zoom(target_node: Node, zoom_scale: float, duration: float):
	var cam = get_node_or_null("/root/BattleScene/BattleCamera")
	if cam and cam.has_method("zoom_to_target"):
		cam.zoom_to_target(target_node, zoom_scale, duration * 0.7)
		await get_tree().create_timer(duration * 0.3).timeout
		if cam.has_method("zoom_to_original"):
			cam.zoom_to_original(duration * 0.3)

# Brief slowmo effect for dramatic moments
func _brief_slowmo(duration: float, time_scale: float = 0.3):
	var original_scale = Engine.time_scale
	Engine.time_scale = time_scale
	
	await get_tree().create_timer(duration * time_scale).timeout  # Timer affected by time scale
	
	Engine.time_scale = original_scale
