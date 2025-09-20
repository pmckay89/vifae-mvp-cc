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
		
		# Show persistent status icon with proper routing
		var target = effect_data.get("target")
		if target and (target.name == "Player1" or target.name == "Player2"):
			# Player status icon
			CombatUI.show_player_status_icon(target.name, effect_type)
		else:
			# Enemy status icon (for enemy targets or no target)
			CombatUI.show_status_icon(effect_type)
	
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
			
			# Hide persistent status icon
			CombatUI.hide_status_icon(effect_type)
			return

# Clear all effects
func clear_effects():
	print("🧪 [StatusEffectManager] Cleared all effects")
	
	# Hide all persistent status icons
	for effect in active_effects:
		var effect_type = effect.get("type")
		if effect_type:
			CombatUI.hide_status_icon(effect_type)
	
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
		# DOT effects: stack damage, refresh duration
		"poison", "burn", "bleed":
			existing_effect["duration"] = new_effect.get("duration", existing_effect.get("duration", 5))
			existing_effect["stacks"] = existing_effect.get("stacks", 1) + new_effect.get("stacks", 1)
			print("🧪 [StatusEffectManager] ", effect_type.capitalize(), " stacked - stacks: ", existing_effect["stacks"], " duration: ", existing_effect["duration"])
		
		# Charge-based effects: add charges
		"damage_boost", "critical_boost", "reflect", "focus":
			existing_effect["charges"] = existing_effect.get("charges", 1) + new_effect.get("charges", 1)
			print("🧪 [StatusEffectManager] ", effect_type.capitalize(), " charges added - total: ", existing_effect["charges"])
		
		# Shield: add shield HP
		"shield":
			existing_effect["shield_hp"] = existing_effect.get("shield_hp", 0) + new_effect.get("shield_hp", 50)
			print("🧪 [StatusEffectManager] Shield HP added - total: ", existing_effect["shield_hp"])
		
		# Duration-based effects: refresh duration, keep strongest values
		"vulnerable", "armor_up", "stun", "confusion", "regeneration", "resolve_gain", "rage", "weakness", "haste":
			existing_effect["duration"] = new_effect.get("duration", existing_effect.get("duration", 3))
			# Keep the stronger effect values (only for numeric values)
			for key in new_effect.keys():
				if key != "duration" and key != "type" and key != "target" and key != "caster":
					var existing_val = existing_effect.get(key, 0)
					var new_val = new_effect.get(key, 0)
					# Only use max() if both values are numbers
					if typeof(existing_val) == TYPE_INT or typeof(existing_val) == TYPE_FLOAT:
						if typeof(new_val) == TYPE_INT or typeof(new_val) == TYPE_FLOAT:
							existing_effect[key] = max(existing_val, new_val)
						else:
							existing_effect[key] = existing_val  # Keep existing value
					else:
						existing_effect[key] = new_val  # Use new value
			print("🧪 [StatusEffectManager] ", effect_type.capitalize(), " refreshed - duration: ", existing_effect["duration"])

		# Barrier: add absorption amounts
		"barrier":
			existing_effect["absorb_amount"] = existing_effect.get("absorb_amount", 0) + new_effect.get("absorb_amount", 30)
			print("🧪 [StatusEffectManager] Barrier absorption added - total: ", existing_effect["absorb_amount"])
		
		# Mark: doesn't stack, just refresh
		"mark":
			print("🧪 [StatusEffectManager] Mark already active - no change")
		
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
		# Damage Over Time
		"poison":
			_process_poison_effect(effect, effect_index)
		"burn":
			_process_burn_effect(effect, effect_index)
		"bleed":
			_process_bleed_effect(effect, effect_index)
		
		# Damage Modifiers
		"vulnerable":
			_process_vulnerable_effect(effect, effect_index)
		"damage_boost":
			_process_damage_boost_effect(effect, effect_index)
		"critical_boost":
			_process_critical_boost_effect(effect, effect_index)
		
		# Defense/Mitigation
		"shield":
			_process_shield_effect(effect, effect_index)
		"armor_up":
			_process_armor_up_effect(effect, effect_index)
		"reflect":
			_process_reflect_effect(effect, effect_index)
		
		# Turn Control
		"stun":
			_process_stun_effect(effect, effect_index)
		"confusion":
			_process_confusion_effect(effect, effect_index)
		"focus":
			_process_focus_effect(effect, effect_index)
		
		# Healing/Recovery
		"regeneration":
			_process_regeneration_effect(effect, effect_index)
		"resolve_gain":
			_process_resolve_gain_effect(effect, effect_index)
		
		# New Status Effects
		"rage":
			_process_rage_effect(effect, effect_index)
		"weakness":
			_process_weakness_effect(effect, effect_index)
		"haste":
			_process_haste_effect(effect, effect_index)
		"barrier":
			_process_barrier_effect(effect, effect_index)

		# Unique Effects
		"mark":
			_process_mark_effect(effect, effect_index)

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
	
	# Apply damage to target (uses centralized calculation)
	target.take_damage(total_damage)
	
	# Show poison popup visual
	CombatUI.show_poison_popup(target, total_damage)
	
	# Reduce duration
	effect["duration"] = duration - 1
	
	# Remove if expired
	if effect["duration"] <= 0:
		print("☠️ [StatusEffectManager] Poison expired")
		active_effects.remove_at(effect_index)

# Process burn DOT effect (fire-based)
func _process_burn_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var stacks = effect.get("stacks", 1)
	var damage_per_stack = effect.get("damage_per_stack", 12) # Slightly less than poison
	var duration = effect.get("duration", 4)
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	var total_damage = stacks * damage_per_stack
	print("🔥 [StatusEffectManager] Burn deals ", total_damage, " damage (", stacks, " stacks)")
	
	# Apply damage to target (uses centralized calculation)
	target.take_damage(total_damage)
	
	# Show burn popup visual
	CombatUI.show_burn_popup(target, total_damage)
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("🔥 [StatusEffectManager] Burn expired")
		active_effects.remove_at(effect_index)
		CombatUI.hide_status_icon("burn")

# Process bleed DOT effect (physical)
func _process_bleed_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var stacks = effect.get("stacks", 1)
	var damage_per_stack = effect.get("damage_per_stack", 10) # Weakest DOT
	var duration = effect.get("duration", 6) # But lasts longer
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	var total_damage = stacks * damage_per_stack
	print("🩸 [StatusEffectManager] Bleed deals ", total_damage, " damage (", stacks, " stacks)")
	
	# Apply damage to target (uses centralized calculation)
	target.take_damage(total_damage)
	
	# Show bleed popup visual
	CombatUI.show_bleed_popup(target, total_damage)
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("🩸 [StatusEffectManager] Bleed expired")
		active_effects.remove_at(effect_index)

# Process vulnerable effect (takes +50% damage)
func _process_vulnerable_effect(effect: Dictionary, effect_index: int):
	var duration = effect.get("duration", 3)
	
	# This is a passive effect - it modifies incoming damage
	# The actual damage modification happens in take_damage() methods
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("🎯 [StatusEffectManager] Vulnerable expired")
		active_effects.remove_at(effect_index)

# Process damage boost effect (next N attacks +100% damage)
func _process_damage_boost_effect(effect: Dictionary, effect_index: int):
	var charges = effect.get("charges", 3)
	
	# This is a passive effect - it modifies outgoing damage
	# Charges are consumed when attacks are made
	
	# No duration reduction - this effect expires by charge consumption
	print("💪 [StatusEffectManager] Damage boost active (", charges, " charges remaining)")

# Process critical boost effect (next N attacks guaranteed crit)
func _process_critical_boost_effect(effect: Dictionary, effect_index: int):
	var charges = effect.get("charges", 2)
	
	# This is a passive effect - it modifies crit chance
	# Charges are consumed when attacks are made
	
	print("✨ [StatusEffectManager] Critical boost active (", charges, " charges remaining)")

# Process shield effect (absorbs X damage)
func _process_shield_effect(effect: Dictionary, effect_index: int):
	var shield_hp = effect.get("shield_hp", 50)
	
	# This is a passive effect - it absorbs damage
	# Shield HP is reduced when damage is taken
	
	print("🛡️ [StatusEffectManager] Shield active (", shield_hp, " HP remaining)")
	if shield_hp <= 0:
		print("🛡️ [StatusEffectManager] Shield broken")
		active_effects.remove_at(effect_index)

# Process armor up effect (reduces all damage by X points)
func _process_armor_up_effect(effect: Dictionary, effect_index: int):
	var duration = effect.get("duration", 5)
	var armor_value = effect.get("armor_value", 5)
	
	# This is a passive effect - it reduces incoming damage
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("⚔️ [StatusEffectManager] Armor up expired")
		active_effects.remove_at(effect_index)
	else:
		print("⚔️ [StatusEffectManager] Armor up active (", armor_value, " reduction, ", effect["duration"], " turns)")

# Process reflect effect (next N attacks bounce 50% damage)
func _process_reflect_effect(effect: Dictionary, effect_index: int):
	var charges = effect.get("charges", 2)
	var reflect_percent = effect.get("reflect_percent", 50)
	
	# This is a passive effect - it reflects damage back to attacker
	# Charges are consumed when attacks are reflected
	
	print("🪞 [StatusEffectManager] Reflect active (", charges, " charges, ", reflect_percent, "% damage)")

# Process stun effect (skip turn)
func _process_stun_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var duration = effect.get("duration", 1)
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	# Stun prevents the target from acting
	# This will be handled by TurnManager checking for stun before allowing actions
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("😵 [StatusEffectManager] Stun expired")
		active_effects.remove_at(effect_index)
	else:
		print("😵 [StatusEffectManager] ", target.name, " is stunned (", effect["duration"], " turns)")

# Process confusion effect (50% chance to attack random target)
func _process_confusion_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var duration = effect.get("duration", 2)
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	# Confusion affects target selection
	# This will be handled by TurnManager during target selection
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("🌀 [StatusEffectManager] Confusion expired")
		active_effects.remove_at(effect_index)
	else:
		print("🌀 [StatusEffectManager] ", target.name, " is confused (", effect["duration"], " turns)")

# Process focus effect (next ability costs -1 resolve)
func _process_focus_effect(effect: Dictionary, effect_index: int):
	var charges = effect.get("charges", 1)
	
	# This is a passive effect - it reduces resolve costs
	# Charges are consumed when abilities are used
	
	print("🎯 [StatusEffectManager] Focus active (", charges, " charges remaining)")

# Process regeneration effect (heals X HP per turn)
func _process_regeneration_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var heal_per_turn = effect.get("heal_per_turn", 15)
	var duration = effect.get("duration", 4)
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	# Heal the target
	if target.has_method("heal"):
		target.heal(heal_per_turn)
		print("💚 [StatusEffectManager] Regeneration heals ", target.name, " for ", heal_per_turn, " HP")
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("💚 [StatusEffectManager] Regeneration expired")
		active_effects.remove_at(effect_index)

# Process resolve gain effect (+1 resolve per turn)
func _process_resolve_gain_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	var resolve_per_turn = effect.get("resolve_per_turn", 1)
	var duration = effect.get("duration", 3)
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	# Grant resolve to the target
	if target.has_method("gain_resolve"):
		target.gain_resolve(resolve_per_turn)
		print("🔋 [StatusEffectManager] Resolve gain grants ", target.name, " +", resolve_per_turn, " resolve")
	
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		print("🔋 [StatusEffectManager] Resolve gain expired")
		active_effects.remove_at(effect_index)

# Process mark effect (next attack deals double damage, then expires)
func _process_mark_effect(effect: Dictionary, effect_index: int):
	var target = effect.get("target")
	
	if not target or target.is_defeated:
		active_effects.remove_at(effect_index)
		return
	
	# Mark is a passive effect that doubles the next attack damage
	# It expires when an attack hits the marked target
	
	print("🎯 [StatusEffectManager] ", target.name, " is marked (next attack deals double damage)")

# Centralized damage calculation system
func calculate_final_damage(attacker: Node, target: Node, base_damage: int) -> Dictionary:
	var result = {
		"final_damage": base_damage,
		"absorbed": 0,
		"effects_triggered": []
	}
	
	if base_damage <= 0:
		return result
	
	var working_damage = float(base_damage)
	var attacker_name = "unknown" if attacker == null else attacker.name
	var target_name = "unknown" if target == null else target.name
	print("🧮 [StatusEffectManager] Calculating damage: ", base_damage, " from ", attacker_name, " to ", target_name)

	# Apply attacker upgrade bonuses (multiplicative)
	if attacker and attacker_name in ["Player1", "Player2"]:
		if ProgressManager.has_player_upgrade(attacker_name, "combat_training"):
			working_damage *= 1.1
			print("🔼 [Upgrade] Combat Training: ", working_damage / 1.1, " → ", working_damage)

		if ProgressManager.has_player_upgrade(attacker_name, "battle_veteran"):
			working_damage *= 1.2
			print("🔼 [Upgrade] Battle Veteran: damage bonus applied")

		if ProgressManager.has_player_upgrade(attacker_name, "master_combatant"):
			working_damage *= 1.5
			print("🔼 [Upgrade] Master Combatant: ", working_damage / 1.5, " → ", working_damage)

		if ProgressManager.has_player_upgrade(attacker_name, "berserker_might"):
			working_damage *= 1.25
			print("🔼 [Upgrade] Berserker Might: ", working_damage / 1.25, " → ", working_damage)

		# Check for Dual Wielding (party-wide upgrade, check if ANY player has it)
		if ProgressManager.has_player_upgrade("Player1", "dual_wielding") or ProgressManager.has_player_upgrade("Player2", "dual_wielding"):
			working_damage *= 1.15
			print("🔼 [Upgrade] Dual Wielding: ", working_damage / 1.15, " → ", working_damage)

		# Check for First Strike (double damage on first attack each battle)
		if ProgressManager.has_player_upgrade(attacker_name, "first_strike"):
			# Check if this is the first attack this battle for this player
			var first_attack_key = attacker_name + "_first_attack_used"
			var flag_value = ProgressManager.get_battle_flag(first_attack_key)
			print("🔍 [First Strike] Checking ", attacker_name, " flag: ", first_attack_key, " = ", flag_value)
			if not flag_value:
				working_damage *= 2.0
				ProgressManager.set_battle_flag(first_attack_key, true)
				print("🔼 [Upgrade] First Strike: ", working_damage / 2.0, " → ", working_damage)
			else:
				print("🔍 [First Strike] Already used for ", attacker_name, " this battle")

		# Check for Finishing Blow (+200% damage to enemies below 25% HP)
		if ProgressManager.has_player_upgrade(attacker_name, "finishing_blow"):
			if target and "hp" in target and "hp_max" in target:
				var target_hp_percent = float(target.hp) / float(target.hp_max)
				if target_hp_percent < 0.25:
					working_damage *= 3.0  # +200% = 3x total damage
					print("🔼 [Upgrade] Finishing Blow: ", working_damage / 3.0, " → ", working_damage)
	
	# Apply defensive multiplicative effects on target (mark, vulnerable)
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		if effect.get("target") == target:
			match effect.get("type"):
				"mark":
					working_damage *= 2.0
					result.effects_triggered.append("mark")
					print("🎯 [StatusEffectManager] Mark triggered! Damage: ", base_damage, " → ", working_damage)
					# Remove mark effect after consumption
					active_effects.remove_at(i)
					CombatUI.hide_status_icon("mark")
				"vulnerable":
					working_damage *= 1.5
					result.effects_triggered.append("vulnerable")
					print("🎯 [StatusEffectManager] Vulnerable triggered! +50% damage")
	
	# Apply flat damage reductions on target (armor_up)
	for effect in active_effects:
		if effect.get("target") == target and effect.get("type") == "armor_up":
			var armor_value = effect.get("armor_value", 5)
			working_damage = max(0, working_damage - armor_value)
			result.effects_triggered.append("armor_up")
			print("⚔️ [StatusEffectManager] Armor reduced damage by ", armor_value, " points")
	
	# Apply absorption effects on target (shield)
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		if effect.get("target") == target and effect.get("type") == "shield":
			var shield_hp = effect.get("shield_hp", 0)
			var absorbed = min(working_damage, shield_hp)
			working_damage -= absorbed
			result.absorbed += absorbed
			
			# Update shield HP
			effect["shield_hp"] = shield_hp - absorbed
			
			if effect["shield_hp"] <= 0:
				# Shield broken, remove effect
				active_effects.remove_at(i)
				CombatUI.hide_status_icon("shield")
				print("🛡️ [StatusEffectManager] Shield absorbed ", absorbed, " damage and broke!")
				result.effects_triggered.append("shield_broken")
			else:
				print("🛡️ [StatusEffectManager] Shield absorbed ", absorbed, " damage (", effect["shield_hp"], " HP remaining)")
				result.effects_triggered.append("shield")
			break  # Only one shield effect per target

	# Apply target defense upgrade bonuses (multiplicative)
	if target and target_name in ["Player1", "Player2"]:
		# Check for Last Stand (50% less damage when below 30% HP)
		if ProgressManager.has_player_upgrade(target_name, "last_stand"):
			if target and "hp" in target and "hp_max" in target:
				var target_hp_percent = float(target.hp) / float(target.hp_max)
				if target_hp_percent < 0.30:
					working_damage *= 0.5  # 50% less damage
					print("🔽 [Upgrade] Last Stand: 50% damage reduction applied")

	if target and target_name in ["Player1", "Player2"]:
		if ProgressManager.has_player_upgrade(target_name, "thick_skin"):
			working_damage *= 0.9  # -10% damage taken
			print("🔽 [Upgrade] Thick Skin: ", working_damage / 0.9, " → ", working_damage)

		if ProgressManager.has_player_upgrade(target_name, "battle_veteran"):
			working_damage *= 0.9  # +10% defense (battle veteran gives both offense and defense)
			print("🔽 [Upgrade] Battle Veteran: defense bonus applied")

		if ProgressManager.has_player_upgrade(target_name, "berserker_might"):
			working_damage *= 1.1  # -10% defense penalty
			print("🔽 [Upgrade] Berserker Might: defense penalty applied")

	# Apply flat damage reduction upgrades (after multiplicative)
	if target and target_name in ["Player1", "Player2"]:
		if ProgressManager.has_player_upgrade(target_name, "armor_plating"):
			var reduction = min(working_damage, 5)  # Reduce by 5, but not below 0
			working_damage -= reduction
			print("🔽 [Upgrade] Armor Plating: reduced by ", reduction, " points")

	result.final_damage = int(round(working_damage))
	print("🧮 [StatusEffectManager] Final damage: ", result.final_damage, " (absorbed: ", result.absorbed, ")")

	# Apply Vampire Fang lifesteal after damage is calculated
	if attacker and attacker_name in ["Player1", "Player2"] and result.final_damage > 0:
		if ProgressManager.has_player_upgrade(attacker_name, "vampire_fang"):
			var lifesteal_amount = int(result.final_damage * 0.25)  # 25% lifesteal
			if lifesteal_amount > 0:
				attacker.hp = min(attacker.hp + lifesteal_amount, attacker.hp_max)
				print("🩸 [Upgrade] Vampire Fang: healed ", attacker_name, " for ", lifesteal_amount, " HP")
				# Update UI to show new HP
				CombatUI.update_hp_bar(attacker_name, attacker.hp, attacker.hp_max)
				result.effects_triggered.append("vampire_fang")

		# Apply Bloodlust lifesteal after damage is calculated (only on 50+ damage)
		if ProgressManager.has_player_upgrade(attacker_name, "bloodlust") and result.final_damage >= 50:
			var bloodlust_amount = int(result.final_damage * 0.25)  # 25% lifesteal like Vampire Fang
			if bloodlust_amount > 0:
				attacker.hp = min(attacker.hp + bloodlust_amount, attacker.hp_max)
				print("🩸 [Upgrade] Bloodlust: healed ", attacker_name, " for ", bloodlust_amount, " HP (50+ damage trigger)")
				# Update UI to show new HP
				CombatUI.update_hp_bar(attacker_name, attacker.hp, attacker.hp_max)
				result.effects_triggered.append("bloodlust")

		# Apply Weapon Master random double damage
		if ProgressManager.has_player_upgrade(attacker_name, "weapon_master"):
			if randf() < 0.20:  # 20% chance
				# This applies AFTER all other calculations, so we need to recalculate
				# But since this is post-calculation, we'll just double the final result
				var bonus_damage = result.final_damage  # Double means +100% of current damage
				result.final_damage += bonus_damage
				print("⚔️ [Upgrade] Weapon Master: DOUBLE DAMAGE! ", result.final_damage - bonus_damage, " → ", result.final_damage)
				result.effects_triggered.append("weapon_master")

	return result

# Process new status effects
func _process_rage_effect(effect: Dictionary, effect_index: int):
	var duration = effect.get("duration", 2)
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		active_effects.remove_at(effect_index)
		print("😡 [StatusEffectManager] Rage effect ended")

func _process_weakness_effect(effect: Dictionary, effect_index: int):
	var duration = effect.get("duration", 3)
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		active_effects.remove_at(effect_index)
		print("💀 [StatusEffectManager] Weakness effect ended")

func _process_haste_effect(effect: Dictionary, effect_index: int):
	var duration = effect.get("duration", 2)
	effect["duration"] = duration - 1
	if effect["duration"] <= 0:
		active_effects.remove_at(effect_index)
		print("💨 [StatusEffectManager] Haste effect ended")

func _process_barrier_effect(effect: Dictionary, effect_index: int):
	# Barrier persists until absorbed, no duration countdown
	pass

# Debug helper
func _debug_print_effects():
	if active_effects.size() > 0:
		print("🧪 [StatusEffectManager] Active effects:")
		for i in range(active_effects.size()):
			var effect = active_effects[i]
			print("  ", i, ": ", effect)
	else:
		print("🧪 [StatusEffectManager] No active effects")
