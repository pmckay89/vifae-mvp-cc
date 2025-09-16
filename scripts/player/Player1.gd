extends Node2D

var hp_max: int = 100
var hp: int = 100
var is_defeated: bool = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()
@onready var status_effects := StatusEffectManager.new()

func _ready():
	rng.randomize()
	add_to_group("players")
	
	# Hide main sprite - using idle_p1 animation through AnimationBridge now
	# $Sprite2D.visible = false  # COMMENTED OUT - AnimationBridge handles this now
	
	# Add StatusEffectManager as child
	add_child(status_effects)
	status_effects.name = "StatusEffects"
	
	ScreenShake.shake(5.0, 0.3)

func start_turn():
	if is_defeated:
		print(name, "is defeated and skips turn.")
		get_node("/root/BattleScene/TurnManager").end_turn()
		return
	print(name, "is ready to act.")

func show_block_animation(duration: float = 1.0):
	# Stop breathing animation during block
	var idle_animation = get_node_or_null("idle")
	if idle_animation and idle_animation.has_method("stop"):
		idle_animation.stop()
	
	# Get references to both sprites
	var main_sprite = $Sprite2D
	var block_sprite = $"p1-block"  # Use quotes for the dash
	
	# Switch to block sprite
	main_sprite.visible = false
	if idle_animation:
		idle_animation.visible = false
	block_sprite.visible = true
	
	# Hold for specified duration
	await get_tree().create_timer(duration).timeout
	
	# Switch back to breathing animation (not main sprite)
	block_sprite.visible = false
	main_sprite.visible = false  # Keep main sprite hidden
	
	# Restart breathing animation
	if idle_animation:
		idle_animation.visible = true
		if idle_animation.has_method("play"):
			idle_animation.play("idle")

func show_death_sprite():
	# Stop breathing animation
	var idle_animation = get_node_or_null("idle")
	if idle_animation and idle_animation.has_method("stop"):
		idle_animation.stop()
	
	# Hide all other sprites
	$Sprite2D.visible = false
	$"p1-block".visible = false
	if idle_animation:
		idle_animation.visible = false
	
	# Show death sprite
	$"p1-dead".visible = true
	print("DEATH→ " + name + " death sprite displayed")

func hide_death_sprite():
	# Hide death sprite and restore breathing animation
	$"p1-dead".visible = false
	$Sprite2D.visible = false  # Keep main sprite hidden
	$"p1-block".visible = false
	
	# Restart breathing animation
	var idle_animation = get_node_or_null("idle")
	if idle_animation:
		idle_animation.visible = true
		if idle_animation.has_method("play"):
			idle_animation.play("idle")
	
	print("REVIVE→ " + name + " restored to life")

func attack(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	
	print("⚔️ " + name + " begins ninja attack sequence!")
	await execute_ninja_attack_sequence(target)
	

# New method for standard QTE system - just handles visual effects after QTE
func perform_attack(qte_result: String, target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	# Play ONLY the animation part, not the full sequence with QTE
	await play_attack_animation_only(target)
	
	# Then apply visual/audio effects based on QTE result
	# Note: TurnManager will handle damage calculation
	match qte_result:
		"crit":
			print("✨ PERFECT NINJA STRIKE!")
			VFXManager.play_hit_effects(target)
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/crit.wav")
				sfx_player.play()
		"normal":
			print("⚔️ Good ninja attack!")
			VFXManager.play_hit_effects(target)
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/attack.wav")
				sfx_player.play()
		"fail":
			print("💫 Ninja attack missed...")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/miss.wav")
				sfx_player.play()

# Animation-only version without QTE or damage
func play_attack_animation_only(target):
	print("🥷 " + name + " ninja animation only!")
	
	# Get references to animation nodes
	var idle_animation = get_node_or_null("idle")
	var combat_animation = get_node_or_null("CombatAnimations")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found!")
		return
	
	# Step 1: Move sprite right toward enemy
	var original_pos = global_position
	var attack_pos = Vector2(original_pos.x + 80, original_pos.y)
	
	# Hide idle animation during attack
	if idle_animation and idle_animation.has_method("stop"):
		idle_animation.stop()
	
	# Step 2: Windup animation
	if combat_animation.has_method("play"):
		combat_animation.play("attackwindup")
		print("🥷 Windup animation started")
		await get_tree().create_timer(0.8).timeout
	
	# Step 3: Attack animation  
	if combat_animation.has_method("play"):
		combat_animation.play("attack")
		print("🥷 Attack animation!")
		await get_tree().create_timer(0.3).timeout
	
	# Step 4: Jump back animation
	if combat_animation.has_method("play"):
		combat_animation.play("jumpback")
		print("🥷 Jumping back...")
		await get_tree().create_timer(0.6).timeout
	
	# Step 5: Restore idle animation
	if idle_animation and idle_animation.has_method("play"):
		idle_animation.play("idle")
	
	print("🥷 Ninja attack animation complete!")

# New split methods for TurnManager integration
# STANDARDIZED ATTACK SYSTEM - Player1 Implementation
func start_attack_windup():
	print("🥷 " + name + " begins ninja windup!")
	
	# Get references to animation nodes
	var idle_animation = get_node_or_null("idle")
	var combat_animation = get_node_or_null("CombatAnimations")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found!")
		return
	
	print("🥷 Found CombatAnimations node: ", combat_animation)
	
	# Hide idle animation during attack
	if idle_animation:
		if idle_animation.has_method("stop"):
			idle_animation.stop()
		idle_animation.visible = false
		print("🥷 Stopped and hid idle animation")
	
	# Play windup animation on AnimatedSprite2D
	if combat_animation is AnimatedSprite2D:
		print("🥷 Playing attackwindup animation on AnimatedSprite2D")
		combat_animation.play("attackwindup")
		combat_animation.visible = true
		await get_tree().create_timer(0.8).timeout
		print("🥷 Windup animation complete")
	else:
		print("❌ CombatAnimations is not AnimatedSprite2D: ", combat_animation.get_class())
	
	print("🥷 Windup complete, ready for QTE!")

func finish_attack_sequence(qte_result: String, target):
	print("🥷 " + name + " finishing attack with result: " + qte_result)
	
	var combat_animation = get_node_or_null("CombatAnimations")
	var idle_animation = get_node_or_null("idle")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found in finish!")
		return
	
	print("🥷 Found CombatAnimations in finish: ", combat_animation)
	
	# Step 1: Attack animation
	if combat_animation is AnimatedSprite2D:
		print("🥷 Playing attack animation on AnimatedSprite2D")
		combat_animation.play("attack")
		combat_animation.visible = true
		await get_tree().create_timer(0.3).timeout
		print("🥷 Attack animation complete")
	else:
		print("❌ CombatAnimations is not AnimatedSprite2D in finish: ", combat_animation.get_class())
	
	# Step 2: Only print feedback (TurnManager handles all audio/damage/hit effects)
	match qte_result:
		"crit":
			print("✨ PERFECT NINJA STRIKE!")
		"normal":
			print("⚔️ Good ninja attack!")
		"fail":
			print("💫 Ninja attack missed...")
	
	# Step 3: Jump back animation
	if combat_animation is AnimatedSprite2D:
		print("🥷 Playing jumpback animation on AnimatedSprite2D")
		combat_animation.play("jumpback")
		combat_animation.visible = true
		await get_tree().create_timer(0.6).timeout
		print("🥷 Jumpback complete")
	
	# Step 4: Hide combat animation and restore idle
	if combat_animation is AnimatedSprite2D:
		combat_animation.visible = false
		print("🥷 Hid combat animation")
	
	if idle_animation:
		idle_animation.visible = true
		if idle_animation.has_method("play"):
			idle_animation.play("idle")
		print("🥷 Restored idle animation")
	
	print("🥷 Ninja attack sequence complete!")

func attack_critical(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	var damage = rng.randi_range(15, 25)
	print(name, "CRITICAL ATTACK on", target.name, "for", damage, "damage!")
	VFXManager.play_hit_effects(target)
	target.take_damage(damage)

func take_damage(amount):
	if is_defeated:
		return
	
	# Use centralized damage calculation system
	var damage_result = status_effects.calculate_final_damage(null, self, amount)
	var final_damage = damage_result.final_damage
	
	# Show effects that triggered
	for effect in damage_result.effects_triggered:
		print("🎯 [", name, "] ", effect, " effect triggered!")

	# Check for barrier absorption
	if status_effects.has_effect("barrier"):
		var barrier_effect = status_effects.find_effect("barrier")
		var absorbed = min(final_damage, barrier_effect.get("absorb_amount", 0))
		if absorbed > 0:
			final_damage -= absorbed
			print("🛡️ BARRIER: Absorbed " + str(absorbed) + " damage")
			CombatUI.show_damage_popup(self, absorbed)
			status_effects.remove_effect("barrier")  # Remove after any damage

	hp -= final_damage
	print(name, "takes", final_damage, "damage. HP:", hp)

	CombatUI.update_hp_bar("Player1", hp, hp_max)  # Use hp_max instead of 100

	if hp <= 0:
		hp = 0
		is_defeated = true
		print(name, "has been defeated!")
		show_death_sprite()

	CombatUI.show_damage_popup(self, final_damage)

func reset_for_new_combat():
	# Called by TurnManager when combat resets
	hp = hp_max
	is_defeated = false
	hide_death_sprite()
	print("RESET→ " + name + " fully restored")

func get_ability_list() -> Array:
	return ["2x_cut", "moonfall_slash", "spirit_wave", "whirlwind", "poison", "burn_strike", "shield_boost", "mark_target", "berserker_rage", "healing_touch", "curse_strike", "time_shift", "energy_barrier", "ghost_attack"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"2x_cut":
			return "2x Cut"
		"moonfall_slash":
			return "Moonfall Slash"
		"spirit_wave":
			return "Spirit Wave"
		"whirlwind":
			return "Whirlwind"
		"poison":
			return "Poison"
		"burn_strike":
			return "Burn Strike"
		"shield_boost":
			return "Shield Boost"
		"mark_target":
			return "Mark Target"
		"berserker_rage":
			return "Berserker Rage"
		"healing_touch":
			return "Healing Touch"
		"curse_strike":
			return "Curse Strike"
		"time_shift":
			return "Time Shift"
		"energy_barrier":
			return "Energy Barrier"
		"ghost_attack":
			return "Ghost Attack"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🎯 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Handle special abilities with custom animations (new contract: return damage info)
	if ability_name == "2x_cut":
		var result = await execute_2x_cut_dual_qte(target)
		return result
	elif ability_name == "whirlwind":
		var result = await execute_whirlwind_sequence(target)
		return result
	elif ability_name == "poison":
		var result = await execute_poison_sequence(target)
		return result
	elif ability_name == "burn_strike":
		var result = await execute_burn_strike_sequence(target)
		return result
	elif ability_name == "shield_boost":
		var result = await execute_shield_boost_sequence(target)
		return result
	elif ability_name == "mark_target":
		var result = await execute_mark_target_sequence(target)
		return result
	elif ability_name == "berserker_rage":
		var result = await execute_berserker_rage_sequence(target)
		return result
	elif ability_name == "healing_touch":
		var result = await execute_healing_touch_sequence(target)
		return result
	elif ability_name == "curse_strike":
		var result = await execute_curse_strike_sequence(target)
		return result
	elif ability_name == "time_shift":
		var result = await execute_time_shift_sequence(target)
		return result
	elif ability_name == "energy_barrier":
		var result = await execute_energy_barrier_sequence(target)
		return result
	elif ability_name == "ghost_attack":
		var result = await execute_ghost_attack_sequence(target)
		return result
	elif ability_name == "uppercut":
		await execute_uppercut_sequence(target)
		return null  # TODO: Convert uppercut to new contract
	else:
		# Call QTEManager to start the QTE for this ability (old system)
		await QTEManager.start_qte_for_ability(self, ability_name, target)
		return null  # Old system handles damage directly

func execute_2x_cut_dual_qte(target):
	print("⚔️ " + name + " begins ninja 2x Cut sequence via AnimationBridge!")
	
	# Step 1: Spawn animation and play windup
	var animation_instance = AnimationBridge.spawn_ability_animation("2x_cut", Vector2.ZERO, self)
	if not animation_instance:
		print("❌ Failed to spawn 2x_cut animation")
		return {"damage": 0, "qte_results": ["fail", "fail"]}
	
	AnimationBridge.play_windup_animation("2x_cut")
	await AnimationBridge.animation_ready_for_qte

	# QTE 1
	print("⚔️ First strike incoming...")
	var result1 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 1st Cut!")
	_play_2x_cut_sound_effect(result1)

	# Apply first damage immediately
	var first_damage = 0
	if result1 in ["crit", "normal"]:
		first_damage = 6 if result1 == "crit" else 4
		target.take_damage(first_damage)
		VFXManager.play_hit_effects(target)

	# Start finish animation after first QTE for better feel
	var first_success = result1 in ["crit", "normal"]
	if first_success:
		print("⚔️ First QTE success - starting finish animation!")
		AnimationBridge.play_result_animation("2x_cut", "normal")

	# Brief pause
	await get_tree().create_timer(0.3).timeout

	# QTE 2 (during animation)
	print("⚔️ Second strike incoming...")
	var result2 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 2nd Cut!")
	_play_2x_cut_sound_effect(result2)

	# Apply second damage immediately
	var second_damage = 0
	if result2 in ["crit", "normal"]:
		second_damage = 6 if result2 == "crit" else 4
		target.take_damage(second_damage)
		VFXManager.play_hit_effects(target)

	# Handle case where first failed but second succeeded
	var second_success = result2 in ["crit", "normal"]
	if not first_success and second_success:
		print("⚔️ Second QTE success - starting finish animation!")
		AnimationBridge.play_result_animation("2x_cut", "normal")
	elif not first_success and not second_success:
		print("⚔️ Both QTEs failed - playing fail animation")
		AnimationBridge.play_result_animation("2x_cut", "fail")

	# Wait for animation to complete
	await AnimationBridge.animation_sequence_complete
	
	# Step 5: Calculate total damage (already applied immediately)
	var total_damage = first_damage + second_damage
	
	print("⚔️ 2x Cut complete - total damage applied: ", total_damage)
	
	# Return info for TurnManager (damage already applied, just need resolve/success tracking)
	return {
		"damage": total_damage,
		"qte_results": [result1, result2],
		"success": total_damage > 0,
		"handled_damage": true  # Flag that damage was already applied
	}

func execute_whirlwind_sequence(target):
	print("🌪️ " + name + " begins Whirlwind sequence via AnimationBridge!")
	
	# Step 1: Spawn animation and play windup
	var animation_instance = AnimationBridge.spawn_ability_animation("whirlwind", Vector2.ZERO, self)
	if not animation_instance:
		print("❌ Failed to spawn whirlwind animation")
		return {"damage": 0, "qte_result": "fail"}
	
	AnimationBridge.play_windup_animation("whirlwind")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: Single QTE (basic attack QTE)  
	print("🌪️ Whirlwind strike incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to unleash!")
	
	# Play sound effect for QTE result
	_play_whirlwind_sound_effect(result)
	
	# IMMEDIATE DAMAGE - Apply damage right after QTE
	var total_damage = 0
	if result in ["crit", "normal"]:
		total_damage = 30 if result == "crit" else 25  # Crit gets 1.5x multiplier from base 25
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		print("🌪️ IMMEDIATE: Whirlwind deals " + str(total_damage) + " damage")
	
	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("whirlwind", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🌪️ Whirlwind complete - damage already applied: ", total_damage)
	
	# Return info for TurnManager (damage already applied)
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": total_damage > 0,
		"handled_damage": true  # Flag that damage was already applied
	}

func execute_poison_sequence(target):
	print("☠️ " + name + " begins Poison sequence via AnimationBridge!")
	
	# Step 1: Spawn animation and play windup
	var animation_instance = AnimationBridge.spawn_ability_animation("poison", Vector2.ZERO, self)
	if not animation_instance:
		print("❌ Failed to spawn poison animation")
		return {"damage": 0, "qte_result": "fail"}
	
	AnimationBridge.play_windup_animation("poison")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: Single QTE (basic attack QTE)
	print("☠️ Poison strike incoming...")
	var result = await QTEManager.start_qte("confirm attack", 500, "Press Z for Poison!")
	
	# Play sound effect for QTE result
	_play_poison_sound_effect(result)
	
	# IMMEDIATE DAMAGE - Apply damage and effects right after QTE
	var total_damage = 0
	if result in ["crit", "normal"]:
		total_damage = 23 if result == "crit" else 15  # Crit gets 1.5x multiplier from base 15
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		
		# Apply poison effect to target
		var poison_effect = {
			"type": "poison",
			"target": target,
			"caster": self,
			"stacks": 1,
			"duration": 5,
			"damage_per_stack": 15
		}
		target.status_effects.apply_effect(poison_effect)
		print("☠️ IMMEDIATE: Applied poison effect and " + str(total_damage) + " damage to ", target.name)
	else:
		# Failed QTE - still deal minimal damage like other abilities
		total_damage = 5
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		print("☠️ IMMEDIATE: Poison QTE failed - weak strike for ", total_damage, " damage")
	
	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("poison", result)
	await AnimationBridge.animation_sequence_complete
	
	print("☠️ Poison complete - damage already applied: ", total_damage)
	
	# Return info for TurnManager (damage already applied)
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,  # Always true since ability was attempted (prevents turn loop)
		"handled_damage": true  # Flag that damage was already applied
	}

func execute_uppercut_sequence(target):
	print("👊 " + name + " begins Uppercut sequence!")
	
	# Get references to animation nodes
	var idle_animation = get_node_or_null("idle")
	var combat_animation = get_node_or_null("CombatAnimations")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found!")
		return
	
	# Step 1: Walk to enemy position
	await walk_to_enemy(target)
	
	# Step 2: QTE for uppercut
	print("👊 Uppercut QTE starting...")
	var result = await QTEManager.start_qte("confirm attack", 500, "Press Z for Uppercut!")
	
	# Step 3: Handle result
	if result == "crit" or result == "normal":
		# Success - play uppercut animation
		print("✨ Uppercut QTE SUCCESS - playing animation!")
		await play_uppercut_animation()
		process_uppercut_result(result, target)
	else:
		# Failure - just walk back
		print("💫 Uppercut QTE FAILED - no animation")
	
	# Step 4: Walk back to original position
	await walk_back_to_start()
	
	print("👊 Uppercut sequence complete!")

func execute_ninja_attack_sequence(target):
	print("🥷 " + name + " begins ninja attack sequence!")
	
	# Get references to animation nodes
	var idle_animation = get_node_or_null("idle")
	var combat_animation = get_node_or_null("CombatAnimations")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found!")
		return
	
	# Step 1: Move sprite right toward enemy
	var original_pos = global_position
	var attack_pos = Vector2(original_pos.x + 80, original_pos.y)  # Move right toward enemy
	
	# Hide idle animation, keep using idle sprite but move it
	if idle_animation:
		idle_animation.visible = false
	
	# Show combat animation node and move right  
	combat_animation.visible = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", attack_pos, 0.3)
	await tween.finished
	
	# Step 2: Play wind-up animation
	print("🥷 Wind-up phase...")
	combat_animation.play("attackwindup")
	await get_tree().create_timer(0.5).timeout  # 4 frames at 8 fps = 0.5 seconds
	
	# Step 3: QTE between wind-up and attack
	print("🥷 QTE starting...")
	var result = await QTEManager.start_qte("confirm attack", 500, "Press Z to Attack!")
	
	# Step 4: Play attack animation based on QTE result
	if result == "crit" or result == "normal":
		print("✨ Attack QTE SUCCESS - playing attack animation!")
		combat_animation.play("attack")
		await get_tree().create_timer(0.58).timeout  # 7 frames at 12 fps = ~0.58 seconds
		process_ninja_attack_result(result, target)
	else:
		print("💫 Attack QTE FAILED - weak attack")
		combat_animation.play("attack")
		await get_tree().create_timer(0.58).timeout
		process_ninja_attack_result("fail", target)
	
	# Step 5: Play jumpback animation
	print("🥷 Jumping back...")
	combat_animation.play("jumpback")
	await get_tree().create_timer(0.7).timeout  # 7 frames at 10 fps = 0.7 seconds
	
	# Step 6: Return to original position and restore idle
	tween = create_tween()
	tween.tween_property(self, "global_position", original_pos, 0.3)
	await tween.finished
	
	# Hide combat animations and restore idle breathing
	combat_animation.visible = false
	combat_animation.stop()
	
	if idle_animation:
		idle_animation.visible = true
		idle_animation.play("idle")
	
	print("🥷 Ninja attack sequence complete!")

# TEST STATUS EFFECTS - Burn Strike (DOT)
func execute_burn_strike_sequence(target):
	print("🔥 " + name + " begins Burn Strike sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🔥 Burn strike incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to ignite!")
	
	# IMMEDIATE DAMAGE - Apply damage and effects right after QTE
	var total_damage = 0
	if result in ["crit", "normal"]:
		total_damage = 20 if result == "crit" else 12
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		
		# Apply burn effect to target
		var burn_effect = {
			"type": "burn",
			"target": target,
			"caster": self,
			"stacks": 1,
			"duration": 4,
			"damage_per_stack": 12
		}
		target.status_effects.apply_effect(burn_effect)
		print("🔥 IMMEDIATE: Applied burn effect and " + str(total_damage) + " damage to ", target.name)
		
		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "burn")
	else:
		total_damage = 4
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		print("🔥 IMMEDIATE: Burn QTE failed - weak strike for ", total_damage, " damage")
	
	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🔥 Burn strike complete - damage already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true  # Flag that damage was already applied
	}

# TEST STATUS EFFECTS - Shield Boost (Self-buff)
func execute_shield_boost_sequence(target):
	print("🛡️ " + name + " begins Shield Boost sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🛡️ Shield boost incoming...")
	var result = await QTEManager.start_qte("confirm attack", 700, "Press Z to shield!")
	
	# IMMEDIATE EFFECT - Apply shield immediately after QTE  
	var total_damage = 0
	if result in ["crit", "normal"]:
		var shield_hp = 75 if result == "crit" else 50
		
		# Apply shield effect to self
		var shield_effect = {
			"type": "shield",
			"target": self,
			"caster": self,
			"shield_hp": shield_hp
		}
		self.status_effects.apply_effect(shield_effect)
		print("🛡️ IMMEDIATE: Applied shield (", shield_hp, " HP) to ", self.name)
		
		# Show status applied popup
		CombatUI.show_status_applied_popup(self, "shield")
		
		# Shield abilities deal no damage but are successful
		total_damage = 0
	else:
		print("🛡️ IMMEDIATE: Shield QTE failed - no shield granted")
		total_damage = 0
	
	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🛡️ Shield boost complete - effects already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true  # Flag that effects were already applied
	}

# TEST STATUS EFFECTS - Mark Target (Utility debuff)
func execute_mark_target_sequence(target):
	print("🎯 " + name + " begins Mark Target sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🎯 Mark target incoming...")
	var result = await QTEManager.start_qte("confirm attack", 500, "Press Z to mark!")
	
	# Play sound effect for QTE result
	_play_mark_target_sound_effect(result)
	
	# IMMEDIATE EFFECT/DAMAGE - Apply immediately after QTE
	var total_damage = 0
	if result in ["crit", "normal"]:
		# Apply mark effect to target (no damage from this ability)
		var mark_effect = {
			"type": "mark",
			"target": target,
			"caster": self
		}
		target.status_effects.apply_effect(mark_effect)
		print("🎯 IMMEDIATE: Applied mark to ", target.name, " - next attack deals double damage!")
		
		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "mark")
		
		# No damage - this is a strategic setup ability
		total_damage = 0
	else:
		total_damage = 2
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		print("🎯 IMMEDIATE: Mark QTE failed - weak strike for ", total_damage, " damage")
	
	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🎯 Mark target complete - effects already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true  # Flag that damage/effects were already applied
	}

func process_ninja_attack_result(result: String, target):
	var damage = 0
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	match result:
		"crit":
			damage = 15
			print("✨ PERFECT NINJA STRIKE! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			damage = 10
			print("⚔️ Good ninja attack! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			damage = 5
			print("💫 Weak ninja strike... " + str(damage) + " damage.")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func walk_to_enemy(target):
	print("🚶 Walking to enemy...")
	
	# Hide idle breathing animation
	var idle_animation = get_node_or_null("idle")
	if idle_animation:
		idle_animation.visible = false
	
	# Show combat animation node and play walk
	var combat_animation = get_node_or_null("CombatAnimations")
	if combat_animation:
		combat_animation.visible = true
		combat_animation.play("walk")
	
	# Get enemy position (closer to camera)
	var original_pos = global_position
	var enemy_pos = target.global_position
	var attack_position = Vector2(enemy_pos.x - 300, enemy_pos.y)  # In front of enemy (closer to camera)
	
	print("🚶 WALK DEBUG:")
	print("  Player start pos: ", original_pos)
	print("  Enemy pos: ", enemy_pos)
	print("  Attack target pos: ", attack_position)
	print("  Distance to move: ", original_pos.distance_to(attack_position))
	
	# Tween to enemy position
	var tween = create_tween()
	tween.tween_property(self, "global_position", attack_position, 1.0)
	await tween.finished
	
	print("  Player final pos: ", global_position)
	
	# Stop walking animation
	if combat_animation:
		combat_animation.stop()

func walk_back_to_start():
	print("🚶 Walking back to start...")
	
	var combat_animation = get_node_or_null("CombatAnimations")
	var idle_animation = get_node_or_null("idle")
	
	# Play walk animation going back
	if combat_animation:
		combat_animation.play("walk")
	
	# Return to original position (Player1 starts at around 179, 221)
	var start_position = Vector2(179, 221)
	var tween = create_tween()
	tween.tween_property(self, "global_position", start_position, 1.0)
	await tween.finished
	
	# Hide combat animations and restore idle breathing
	if combat_animation:
		combat_animation.visible = false
		combat_animation.stop()
	
	if idle_animation:
		idle_animation.visible = true
		idle_animation.play("idle")

func play_uppercut_animation():
	print("👊 Playing uppercut animation...")
	
	var combat_animation = get_node_or_null("CombatAnimations")
	if combat_animation:
		combat_animation.play("uppercut")
		# Wait for animation to complete (7 frames at 12 fps = ~0.58 seconds)
		await get_tree().create_timer(0.6).timeout

func process_uppercut_result(result: String, target):
	var damage = 0
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	match result:
		"crit":
			damage = 25
			print("✨ PERFECT UPPERCUT! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			damage = 18
			print("👊 Good uppercut! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()

func process_2x_cut_result(result: String, target, strike_number: int):
	var damage = 0
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	match result:
		"crit":
			damage = 10
			print("✨ Strike " + str(strike_number) + " - PERFECT! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			damage = 7
			print("⚔️ Strike " + str(strike_number) + " - Good hit! " + str(damage) + " damage!")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			damage = 5
			print("💫 Strike " + str(strike_number) + " - Weak hit... " + str(damage) + " damage.")
			VFXManager.play_hit_effects(target)
			target.take_damage(damage)
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func on_qte_result(result: String, target):
	if target == null:
		print("❌ Target is null!")
		return
	
	if is_defeated:
		print("❌ " + name + " is defeated and cannot act!")
		return
	
	var damage = 0
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	match selected_ability:
		"moonfall_slash":
			# Damage is now handled individually by each moon impact
			var hit_count = int(result)
			var moon_count = (hit_count + 1) / 2  # Every 2 hits = 1 moon
			print("🌙 " + name + " unleashes Moonfall Slash barrage!")
			print("  → " + str(hit_count) + " rapid strikes summoned " + str(moon_count) + " moons!")
			print("  → Each moon will deal individual damage on impact...")
			
			if hit_count > 0:
				# Visual effects only - damage handled by individual moons
				VFXManager.play_hit_effects(target)
			else:
				print("  → No strikes connected, no moons summoned...")
		
		"spirit_wave":
			match result:
				"crit":
					damage = 30
					print("👻 " + name + " unleashes a PERFECT Spirit Wave! Spectral resonance!")
					print("  → Ethereal echo devastates for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					damage = 20
					print("👻 " + name + " channels Spirit Wave!")
					print("  → Spectral energy strikes for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
				"fail":
					damage = 10
					print("💫 " + name + " loses focus on Spirit Wave...")
					print("  → Weak echo deals only " + str(damage) + " damage.")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		_:
			print("⚠️ Unknown ability: " + selected_ability)

# Sound effect helper for 2x_cut modular system
func _play_2x_cut_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

# Sound effect helper for whirlwind modular system
func _play_whirlwind_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

# Sound effect helper for poison modular system
func _play_poison_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

# Sound effect helper for mark target modular system
func _play_mark_target_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

# New Status Effect Abilities
func execute_berserker_rage_sequence(target):
	print("😡 " + name + " begins Berserker Rage sequence!")

	# Step 1: Spawn animation and play windup
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("😡 Berserker rage incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z for RAGE!")

	# Step 3: IMMEDIATE - Apply rage to self
	var total_damage = _apply_berserker_rage_immediate(self, result)

	# Step 4: Play result animation
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete

	print("😡 Berserker rage complete - rage applied to self")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

func _apply_berserker_rage_immediate(target, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var rage_effect = {
			"type": "rage",
			"target": target,
			"caster": self,
			"duration": 2,
			"damage_modifier": 2.0,
			"incoming_modifier": 1.25
		}
		target.status_effects.apply_effect(rage_effect)
		print("😡 IMMEDIATE: Applied rage to ", target.name, " (+100% damage, +25% incoming)")

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "rage")
		return 0  # No direct damage, just status effect
	else:
		print("😡 IMMEDIATE: Rage failed")
		return 0

func execute_healing_touch_sequence(target):
	print("💚 " + name + " begins Healing Touch sequence!")

	# Step 1: Spawn animation and play windup
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("💚 Healing touch incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to heal!")

	# Step 3: IMMEDIATE - Apply regeneration to self
	var total_damage = _apply_healing_touch_immediate(self, result)

	# Step 4: Play result animation
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete

	print("💚 Healing touch complete - regeneration applied to self")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

func _apply_healing_touch_immediate(target, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var regen_effect = {
			"type": "regeneration",
			"target": target,
			"caster": self,
			"duration": 3,
			"heal_per_turn": 10
		}
		target.status_effects.apply_effect(regen_effect)
		print("💚 IMMEDIATE: Applied regeneration to ", target.name, " (10 HP/turn for 3 turns)")

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "regeneration")
		return 0  # No direct damage, just status effect
	else:
		print("💚 IMMEDIATE: Healing touch failed")
		return 0

func execute_curse_strike_sequence(target):
	print("💀 " + name + " begins Curse Strike sequence!")

	# Step 1: Spawn animation and play windup
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("💀 Curse strike incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to curse!")

	# Step 3: IMMEDIATE - Apply weakness to target
	var total_damage = _apply_curse_strike_immediate(target, result)

	# Step 4: Play result animation
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete

	print("💀 Curse strike complete - weakness applied to target")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

func _apply_curse_strike_immediate(target, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var weakness_effect = {
			"type": "weakness",
			"target": target,
			"caster": self,
			"duration": 3,
			"damage_modifier": 0.5
		}
		target.status_effects.apply_effect(weakness_effect)
		print("💀 IMMEDIATE: Applied weakness to ", target.name, " (50% damage for 3 turns)")

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "weakness")
		return 0  # No direct damage, just status effect
	else:
		print("💀 IMMEDIATE: Curse strike failed")
		return 0

func execute_time_shift_sequence(target):
	print("💨 " + name + " begins Time Shift sequence!")

	# Step 1: Spawn animation and play windup
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("💨 Time shift incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to accelerate!")

	# Step 3: IMMEDIATE - Apply haste to self
	var total_damage = _apply_time_shift_immediate(self, result)

	# Step 4: Play result animation
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete

	print("💨 Time shift complete - haste applied to self")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

func _apply_time_shift_immediate(target, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var haste_effect = {
			"type": "haste",
			"target": target,
			"caster": self,
			"duration": 2
		}
		target.status_effects.apply_effect(haste_effect)
		print("💨 IMMEDIATE: Applied haste to ", target.name, " (extra turn for 2 turns)")

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "haste")
		return 0  # No direct damage, just status effect
	else:
		print("💨 IMMEDIATE: Time shift failed")
		return 0

func execute_energy_barrier_sequence(target):
	print("🛡️ " + name + " begins Energy Barrier sequence!")

	# Step 1: Spawn animation and play windup
	var instance = AnimationBridge.spawn_ability_animation("basic_attack_p1", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack_p1")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("🛡️ Energy barrier incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z for barrier!")

	# Step 3: IMMEDIATE - Apply barrier to self
	var total_damage = _apply_energy_barrier_immediate(self, result)

	# Step 4: Play result animation
	AnimationBridge.play_result_animation("basic_attack_p1", result)
	await AnimationBridge.animation_sequence_complete

	print("🛡️ Energy barrier complete - barrier applied to self")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 👻 Ghost Attack - Using BE_Test1 animations
func execute_ghost_attack_sequence(target):
	print("👻 " + name + " begins Ghost Attack sequence via AnimationBridge!")

	# Step 1: Spawn animation and play windup
	var animation_instance = AnimationBridge.spawn_ability_animation("ghost_attack", Vector2.ZERO, self)
	if not animation_instance:
		print("❌ Failed to spawn ghost attack animation")
		return {"damage": 0, "qte_result": "fail"}

	AnimationBridge.play_windup_animation("ghost_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: Single QTE (basic attack QTE)
	print("👻 Ghost attack incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to unleash!")

	# Play sound effect for QTE result
	_play_ghost_attack_sound_effect(result)

	# IMMEDIATE DAMAGE - Apply damage right after QTE
	var total_damage = 0
	if result in ["crit", "normal"]:
		total_damage = 36 if result == "crit" else 18  # Crit gets 2x multiplier from base 18
		target.take_damage(total_damage)
		VFXManager.play_hit_effects(target)
		print("👻 IMMEDIATE: Ghost Attack deals " + str(total_damage) + " damage")

	# Step 3: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("ghost_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("👻 Ghost Attack complete - damage already applied: ", total_damage)

	# Return info for TurnManager (damage already applied)
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": total_damage > 0,
		"handled_damage": true  # Flag that damage was already applied
	}

func _play_ghost_attack_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return

	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func _apply_energy_barrier_immediate(target, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var barrier_amount = 30 if qte_result == "normal" else 35  # Slightly more for crit
		var barrier_effect = {
			"type": "barrier",
			"target": target,
			"caster": self,
			"absorb_amount": barrier_amount
		}
		target.status_effects.apply_effect(barrier_effect)
		print("🛡️ IMMEDIATE: Applied barrier to ", target.name, " (absorbs ", barrier_amount, " damage)")

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "barrier")
		return 0  # No direct damage, just status effect
	else:
		print("🛡️ IMMEDIATE: Energy barrier failed")
		return 0

# Save/Load methods for SaveManager
func get_current_hp() -> int:
	return hp

func set_hp(new_hp: int):
	hp = clamp(new_hp, 0, hp_max)
	print("[Player1] HP set to: ", hp, "/", hp_max)

func get_resolve() -> int:
	return ResolveManager.player1_resolve

func set_resolve(new_resolve: int):
	ResolveManager.player1_resolve = clamp(new_resolve, 0, ResolveManager.MAX_RESOLVE)
	print("[Player1] Resolve set to: ", ResolveManager.player1_resolve)
