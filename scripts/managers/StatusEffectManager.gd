extends Node
class_name StatusEffectManager

# Modular status effect system
# Handles buffs, debuffs, and DOT effects for players and enemies

# Active effects storage
var active_effects: Array[Dictionary] = []

# Apply a status effect
func apply_effect(effect_data: Dictionary):
	print("🧪 [StatusEffectManager] Applying effect: ", effect_data)
	
	var effect_type = effect_data.get("type", "unknown")
	
	# Check if this effect type already exists (for stacking/refreshing)
	var existing_effect = find_effect(effect_type)
	
	if existing_effect:
		# Handle stacking/refreshing logic
		_handle_existing_effect(existing_effect, effect_data)
	else:
		# Add new effect
		active_effects.append(effect_data.duplicate())
		print("🧪 [StatusEffectManager] Added new effect: ", effect_type)
	
	_debug_print_effects()

# Find an existing effect by type
func find_effect(effect_type: String) -> Dictionary:
	for effect in active_effects:
		if effect.get("type") == effect_type:
			return effect
	return {}

# Check if a specific effect is active
func has_effect(effect_type: String) -> bool:
	return not find_effect(effect_type).is_empty()

# Get all active effects
func get_active_effects() -> Array[Dictionary]:
	return active_effects.duplicate()

# Remove an effect by type
func remove_effect(effect_type: String):
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].get("type") == effect_type:
			print("🧪 [StatusEffectManager] Removed effect: ", effect_type)
			active_effects.remove_at(i)
			return

# Clear all effects
func clear_effects():
	print("🧪 [StatusEffectManager] Cleared all effects")
	active_effects.clear()

# Process turn-based effects (called by TurnManager)
func process_turn_effects(current_actor: Node):
	print("🧪 [StatusEffectManager] Processing turn effects for: ", current_actor.name)
	
	# Process each effect
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		_process_single_effect(effect, current_actor, i)
	
	_debug_print_effects()

# Handle stacking/refreshing of existing effects
func _handle_existing_effect(existing_effect: Dictionary, new_effect: Dictionary):
	var effect_type = existing_effect.get("type")
	
	match effect_type:
		"poison":
			# Poison: refresh duration, increase stacks
			existing_effect["duration"] = new_effect.get("duration", 5)
			existing_effect["stacks"] = existing_effect.get("stacks", 1) + new_effect.get("stacks", 1)
			print("🧪 [StatusEffectManager] Poison refreshed - stacks: ", existing_effect["stacks"], " duration: ", existing_effect["duration"])
		_:
			# Default: refresh duration, update values
			for key in new_effect.keys():
				existing_effect[key] = new_effect[key]
			print("🧪 [StatusEffectManager] Effect refreshed: ", effect_type)

# Process a single effect during turn processing
func _process_single_effect(effect: Dictionary, current_actor: Node, effect_index: int):
	var effect_type = effect.get("type")
	var caster = effect.get("caster")
	
	# Only process effects when it's the caster's turn
	if current_actor != caster:
		return
	
	match effect_type:
		"poison":
			_process_poison_effect(effect, effect_index)
		_:
			print("🧪 [StatusEffectManager] Unknown effect type: ", effect_type)

# Process poison DOT effect
func _process_poison_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var stacks = effect.get("stacks", 1)
	var damage_per_stack = effect.get("damage_per_stack", 15)
	var duration = effect.get("duration", 5)
	
	if not target or target.is_defeated:
		print("🧪 [StatusEffectManager] Poison target invalid, removing effect")
		active_effects.remove_at(effect_index)
		return
	
	# Deal poison damage
	var total_damage = stacks * damage_per_stack
	print("☠️ [StatusEffectManager] Poison deals ", total_damage, " damage (", stacks, " stacks)")
	
	# Apply damage to target
	target.take_damage(total_damage)
	
	# Show poison popup visual
	CombatUI.show_poison_popup(target, total_damage)
	
	# Reduce duration
	effect["duration"] = duration - 1
	
	# Remove if expired
	if effect["duration"] <= 0:
		print("☠️ [StatusEffectManager] Poison expired")
		active_effects.remove_at(effect_index)

# Debug helper
func _debug_print_effects():
	if active_effects.size() > 0:
		print("🧪 [StatusEffectManager] Active effects:")
		for i in range(active_effects.size()):
			var effect = active_effects[i]
			print("  ", i, ": ", effect)
	else:
		print("🧪 [StatusEffectManager] No active effects")