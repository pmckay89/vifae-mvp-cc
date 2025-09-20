extends Node2D

var hp_max: int = 100
var hp: int = 100
var is_defeated = false
var selected_ability = ""
var has_phoenix_feather = false  # Revival item
var applied_upgrades: Array = []  # Track which HP upgrades have been applied

@onready var rng := RandomNumberGenerator.new()
@onready var status_effects := StatusEffectManager.new()

# Breathing animation variables - sprite swapping system
var breathing_tween: Tween
var breathing_enabled: bool = true
var main_sprite_visible: bool = true

# Muzzle flash variables
var muzzle_flash: ColorRect
var muzzle_flash_tween: Tween

# Focus buff variables
var focus_stacks: int = 0


func _ready():
	rng.randomize()
	add_to_group("players")

	# Apply upgrade effects to base stats
	print("🔍 [DEBUG] Player2 _ready() calling _apply_upgrade_effects...")
	_apply_upgrade_effects()

	# Add StatusEffectManager as child
	add_child(status_effects)
	status_effects.name = "StatusEffects"

	_setup_muzzle_flash()
	_ensure_buff_animation_hidden()
	_setup_new_idle_animation()

func _apply_upgrade_effects():
	# Apply HP upgrades
	print("🔍 [DEBUG] Checking Strong Body for Player2...")
	var has_strong_body = ProgressManager.has_player_upgrade("Player2", "strong_body")
	print("🔍 [DEBUG] Has strong body: ", has_strong_body)
	if has_strong_body and not "strong_body" in applied_upgrades:
		hp_max += 25
		hp += 25  # Also heal current HP
		applied_upgrades.append("strong_body")
		print("UPGRADE→ Player2 Strong Body applied: +25 max HP (now ", hp_max, ")")

	if ProgressManager.has_player_upgrade("Player2", "guardian_blessing") and not "guardian_blessing" in applied_upgrades:
		hp_max += 50
		hp += 50
		applied_upgrades.append("guardian_blessing")
		print("UPGRADE→ Player2 Guardian Blessing applied: +50 max HP (now ", hp_max, ")")

	if ProgressManager.has_player_upgrade("Player2", "legendary_resilience") and not "legendary_resilience" in applied_upgrades:
		hp_max += 100
		hp += 100
		applied_upgrades.append("legendary_resilience")
		print("UPGRADE→ Player2 Legendary Resilience applied: +100 max HP (now ", hp_max, ")")

func start_turn():
	if is_defeated:
		print(name, "is defeated and skips turn.")
		get_node("/root/BattleScene/TurnManager").end_turn()
		return
	print(name, "is ready to act.")

# Universal damage system - routes through centralized calculation for upgrade bonuses
func apply_damage(target: Node, base_damage: int) -> Dictionary:
	if not target or not "status_effects" in target:
		print("⚠️ Target has no status_effects, using fallback damage")
		if target and target.has_method("take_damage"):
			target.take_damage(base_damage)
		return {"final_damage": base_damage, "absorbed": 0, "effects_triggered": []}

	# Use centralized damage calculation system for upgrade bonuses
	var damage_result = target.status_effects.calculate_final_damage(self, target, base_damage)
	var final_damage = damage_result.final_damage

	# Apply damage directly (bypassing target.take_damage to avoid double-processing)
	target.hp = max(target.hp - final_damage, 0)

	# Update UI and effects
	CombatUI.update_hp_bar(target.name, target.hp, target.hp_max)
	CombatUI.show_damage_popup(target, final_damage)

	# Check for defeat
	if target.hp <= 0:
		target.is_defeated = true
		print(target.name + " has been defeated!")

	print("🎯 [" + self.name + "] Applied " + str(final_damage) + " damage to " + target.name + " (base: " + str(base_damage) + ")")

	return damage_result

func show_block_animation(duration: float = 1.0):
	# No longer uses breathing animation system

	# Get references to all sprites with null checks
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")
	var attack_sprite = get_node_or_null("attack")
	var block_sprite = get_node_or_null("p2-block")

	# Hide all other sprites and show block sprite
	if is_instance_valid(main_sprite):
		main_sprite.visible = false
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = false
	if is_instance_valid(attack_sprite):
		attack_sprite.visible = false
	if is_instance_valid(block_sprite):
		block_sprite.visible = true
	
	# Hold for specified duration
	await get_tree().create_timer(duration).timeout
	
	# Switch back to main sprite and hide block sprite
	if is_instance_valid(block_sprite):
		block_sprite.visible = false
	if is_instance_valid(main_sprite):
		main_sprite.visible = true
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = false
	if is_instance_valid(attack_sprite):
		attack_sprite.visible = false
	
	# No longer resumes breathing animation

func show_death_sprite():
	# No longer uses breathing animation system

	# Hide all other sprites - with null checks
	var sprite2d = get_node_or_null("Sprite2D")
	var attack = get_node_or_null("attack")
	var block = get_node_or_null("p2-block")
	var dead = get_node_or_null("p2-dead")

	if is_instance_valid(sprite2d):
		sprite2d.visible = false
	if is_instance_valid(attack):
		attack.visible = false
	if is_instance_valid(block):
		block.visible = false

	# Show death sprite
	if is_instance_valid(dead):
		dead.visible = true
	print("DEATH→ " + name + " death sprite displayed")

func hide_death_sprite():
	# Hide death sprite and restore main sprite - with null checks
	var dead = get_node_or_null("p2-dead")
	var sprite2d = get_node_or_null("Sprite2D")
	var attack = get_node_or_null("attack")
	var block = get_node_or_null("p2-block")

	if is_instance_valid(dead):
		dead.visible = false
	if is_instance_valid(sprite2d):
		sprite2d.visible = true
	if is_instance_valid(attack):
		attack.visible = false
	if is_instance_valid(block):
		block.visible = false

	# No longer resumes breathing animation
	print("REVIVE→ " + name + " restored to life")

func show_attack_windup():
	# Show windup pose during QTE - no longer uses breathing animation

	# Hide all idle sprites and show attack sprite (p2.png windup pose)
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")
	var attack_sprite = get_node_or_null("attack")

	if is_instance_valid(main_sprite):
		main_sprite.visible = false
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = false
	if is_instance_valid(attack_sprite):
		attack_sprite.visible = true
	
	print("[Player2] Showing attack windup pose (p2.png)")

func hide_attack_windup():
	# Hide attack sprite - no longer uses breathing animation
	var attack_sprite = get_node_or_null("attack")
	if is_instance_valid(attack_sprite):
		attack_sprite.visible = false

	print("[Player2] Hiding attack windup pose")

# LEGACY ATTACK SYSTEM - Player2 Implementation
# NOTE: Player2 now uses AnimationBridge system for basic attacks
# These methods remain for compatibility with non-AnimationBridge abilities
func start_attack_windup():
	print("🔫 " + name + " starting legacy attack windup (AnimationBridge now used for basic attacks)")
	show_attack_windup()
	# Small delay for windup animation
	await get_tree().create_timer(0.3).timeout
	print("🔫 Legacy windup complete, ready for QTE!")

func finish_attack_sequence(qte_result: String, target):
	print("🔫 " + name + " finishing legacy attack with result: " + qte_result)
	
	# Brief pause for attack timing
	await get_tree().create_timer(0.2).timeout
	
	# Hide attack pose
	hide_attack_windup()
	
	print("🔫 Gun Girl legacy attack sequence complete!")

# LEGACY METHOD - kept for compatibility with old systems
func attack(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	
	# Show windup pose for basic attack
	show_attack_windup()
	
	var damage = rng.randi_range(5, 10)
	print(name, "attacks", target.name, "for", damage, "damage")
	
	# Small delay to show the windup pose
	await get_tree().create_timer(0.3).timeout
	
	# TurnManager now handles sound effects and hit effects for basic attacks
	print("🔫 Gun Girl basic attack (effects handled by TurnManager)")
	apply_damage(target, damage)
	
	# Hide windup pose after attack
	hide_attack_windup()

func attack_critical(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	
	# Show windup pose for critical attack
	show_attack_windup()
	
	var damage = rng.randi_range(15, 25)
	print(name, "CRITICAL ATTACK on", target.name, "for", damage, "damage!")
	
	# Small delay to show the windup pose
	await get_tree().create_timer(0.3).timeout
	
	VFXManager.play_hit_effects(target)
	apply_damage(target, damage)
	
	# Hide windup pose after attack
	hide_attack_windup()

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

	# Check for pain killer immunity (one-time damage negation)
	if status_effects.has_effect("pain_killer"):
		var pain_killer_effect = status_effects.find_effect("pain_killer")
		var absorbed = min(final_damage, pain_killer_effect.get("absorb_amount", 0))
		if absorbed > 0:
			final_damage -= absorbed
			print("🛡️ PAIN KILLER: Absorbed " + str(absorbed) + " damage")
			CombatUI.show_damage_popup(self, absorbed)
			status_effects.remove_effect("pain_killer")  # Always remove after any damage

	hp -= final_damage
	print(name, "takes", final_damage, "damage. HP:", hp)

	CombatUI.update_hp_bar("Player2", hp, hp_max)  # Use hp_max instead of 100

	if hp <= 0:
		hp = 0

		# Check for Phoenix Feather revival
		if has_phoenix_feather:
			has_phoenix_feather = false  # Consume the feather
			hp = hp_max / 2  # Revive with 50% HP
			print("🔥 PHOENIX FEATHER: ", name, " revives with 50% HP!")
			CombatUI.update_hp_bar("Player2", hp, hp_max)
			CombatUI.show_damage_popup(self, -(hp_max / 2))  # Show healing popup

			# Remove phoenix feather status effect since it's consumed
			status_effects.remove_effect("phoenix_feather")
		else:
			is_defeated = true
			print(name, "has been defeated!")
			show_death_sprite()

	CombatUI.show_damage_popup(self, final_damage)

func reset_for_new_combat():
	# Called by TurnManager when combat resets

	# Apply upgrade effects first (before setting hp = hp_max)
	_apply_upgrade_effects()

	hp = hp_max
	is_defeated = false
	hide_death_sprite()

	# Ensure breathing is active after reset
	resume_breathing_animation()
	print("RESET→ " + name + " fully restored")

func get_ability_list() -> Array:
	# All possible abilities for Player2
	var all_abilities = ["big_shot", "scatter_shot", "grenade", "bullet_rain", "freezing_shot", "armor_piercing", "bleeding_shot", "berserker_rage", "healing_touch", "curse_strike", "time_shift", "energy_barrier"]

	# Filter to only unlocked abilities
	var unlocked_abilities = []
	for ability in all_abilities:
		if ProgressManager.has_player_ability("Player2", ability):
			unlocked_abilities.append(ability)

	return unlocked_abilities

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"big_shot":
			return "Big Shot"
		"scatter_shot":
			return "Scatter Shot"
		"grenade":
			return "Grenade"
		"bullet_rain":
			return "Bullet Rain"
		"freezing_shot":
			return "Freezing Shot"
		"armor_piercing":
			return "Armor Piercing"
		"bleeding_shot":
			return "Bleeding Shot"
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
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🔫 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	
	# Handle modular status abilities (new system)
	if ability_name == "freezing_shot":
		var result = await execute_freezing_shot_sequence(target)
		return result
	elif ability_name == "armor_piercing":
		var result = await execute_armor_piercing_sequence(target)
		return result
	elif ability_name == "bleeding_shot":
		var result = await execute_bleeding_shot_sequence(target)
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
	
	# Handle bridge-animated abilities (grenade, future abilities)
	if not get_bridge_ability_config(ability_name).is_empty():
		await execute_animated_ability(ability_name, target)
		return
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Call QTEManager to start the QTE for this ability (legacy abilities)
	await QTEManager.start_qte_for_ability(self, ability_name, target)

func on_qte_result(result: String, target):
	if target == null and selected_ability != "spirit_slash":
		print("❌ Target is null!")
		return
	
	if is_defeated:
		print("❌ " + name + " is defeated and cannot act!")
		return
	
	var damage = 0
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	
	match selected_ability:
		"big_shot":
			match result:
				"crit":
					damage = 35
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("🎯 " + name + " executes a PERFECT Big Shot! Sniper's dream!")
					print("  → Precision shot devastates for " + str(damage) + " damage!")
					trigger_muzzle_flash("crit")
					apply_damage(target, damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"normal":
					damage = 25
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("🔫 " + name + " lands a solid Big Shot!")
					print("  → Heavy shot hits for " + str(damage) + " damage!")
					trigger_muzzle_flash("normal")
					apply_damage(target, damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"fail":
					damage = 8
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("💨 " + name + " rushes the Big Shot...")
					print("  → Hasty shot grazes for " + str(damage) + " damage.")
					apply_damage(target, damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		"scatter_shot":
			match result:
				"crit", "normal":
					damage = 35
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("💥 " + name + " completes the Scatter Shot sequence! All targets hit!")
					print("  → Devastating spread attack deals " + str(damage) + " damage!")
					trigger_muzzle_flash("normal")  # Use normal for both crit and normal scatter shot
					apply_damage(target, damage)
					sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
				"fail":
					damage = 6
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("💨 " + name + " fails to complete the Scatter Shot sequence...")
					print("  → Incomplete spread reduces damage to " + str(damage) + ".")
					apply_damage(target, damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		_:
			print("⚠️ Unknown ability: " + selected_ability)

# Breathing Animation System - Sprite Swapping
func _start_breathing_animation() -> void:
	# Skip old breathing animation if we have the new idle animation system
	if get_node_or_null("IdleAnimatedSprite"):
		print("[Player2] Skipping old breathing animation - using new idle animation")
		return
		
	if not breathing_enabled:
		return
		
	# Get sprite references
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")
	
	if not main_sprite or not idle2_sprite:
		print("[Player2] Missing sprites for breathing animation - main:", main_sprite != null, " idle2:", idle2_sprite != null)
		return
	
	# Ensure proper initial state
	main_sprite.visible = true
	idle2_sprite.visible = false
	main_sprite_visible = true
	
	# Start breathing loop
	_breathing_loop()
	print("[Player2] Sprite-swapping breathing animation started")

func _breathing_loop() -> void:
	if not breathing_enabled:
		return
	
	# Clean up previous tween if it exists
	if breathing_tween:
		breathing_tween.kill()
	
	# Create new breathing tween
	breathing_tween = create_tween()
	breathing_tween.set_loops()  # Infinite loop
	
	var breath_duration = 2.0  # Slower, more natural breathing
	
	# Breathing cycle: main sprite (1s) -> idle2 sprite (1s) -> repeat
	breathing_tween.tween_callback(_swap_to_idle2).set_delay(breath_duration / 2)
	breathing_tween.tween_callback(_swap_to_main).set_delay(breath_duration / 2)

func _swap_to_idle2() -> void:
	if not breathing_enabled:
		return

	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")

	if is_instance_valid(main_sprite):
		main_sprite.visible = false
		main_sprite_visible = false
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = true

func _swap_to_main() -> void:
	if not breathing_enabled:
		return

	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")

	if is_instance_valid(main_sprite):
		main_sprite.visible = true
		main_sprite_visible = true
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = false

func stop_breathing_animation() -> void:
	breathing_enabled = false
	if breathing_tween:
		breathing_tween.kill()
		breathing_tween = null
	
	# Reset to main sprite visible
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")

	if is_instance_valid(main_sprite):
		main_sprite.visible = true
		main_sprite_visible = true
	if is_instance_valid(idle2_sprite):
		idle2_sprite.visible = false
	
	print("[Player2] Breathing animation stopped")

func resume_breathing_animation() -> void:
	breathing_enabled = true
	_start_breathing_animation()

# Muzzle Flash System - Visual feedback for successful ranged attacks
func _setup_muzzle_flash() -> void:
	# Create muzzle flash visual element
	muzzle_flash = ColorRect.new()
	muzzle_flash.size = Vector2(12, 12)  # Bigger 12x12 flash for visibility
	muzzle_flash.color = Color.WHITE  # Bright white flash - more visible
	muzzle_flash.visible = false
	
	# Position it at the gun muzzle (edge of Gun Girl sprite)
	# Adjusted to be at the right edge of the sprite
	muzzle_flash.position = Vector2(35, -5)  # Right edge of sprite, slightly up
	
	add_child(muzzle_flash)
	print("[Player2] Muzzle flash setup complete")

func _ensure_buff_animation_hidden():
	# Make sure buff animation is stopped and hidden on startup
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		print("[Player2] Found AnimationPlayer, stopping it")
		animation_player.stop()
		print("[Player2] AnimationPlayer stopped, current animation: ", animation_player.current_animation)
		
		# Debug: Check all children and their visibility
		print("[Player2] Checking all children for visibility:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ") visible: ", child.get("visible"))
			if child is AnimatedSprite2D:
				# Don't hide our new idle animation sprite
				if child.name == "IdleAnimatedSprite":
					print("    → Keeping IdleAnimatedSprite visible")
				else:
					child.visible = false
					print("    → Set AnimatedSprite2D to hidden")
			elif child is Sprite2D:
				print("    → Found Sprite2D, visible: ", child.visible)
				# Check if this sprite might be the buff sprite
				if child.name.to_lower().contains("buff") or child.name.to_lower().contains("aura"):
					child.visible = false
					print("    → Hiding potential buff sprite: ", child.name)
		
		print("[Player2] Buff animation cleanup complete")
	else:
		print("[Player2] No AnimationPlayer found during startup")


func activate_focus():
	# Add focus stack
	focus_stacks += 1
	var damage_multiplier = focus_stacks * 2.0  # Each stack = 2x multiplier (stacks: 2x, 4x, 6x, etc.)
	
	print("🌟 " + name + " activates Focus! Stack #" + str(focus_stacks) + " (next attack: " + str(damage_multiplier) + "x damage)")
	
	# Start/continue the buff animation
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.has_animation("buff"):
		if not animation_player.is_playing():
			animation_player.play("buff")
			print("🌟 Buff animation started")
		else:
			print("🌟 Buff animation already playing (stacking)")
	else:
		print("⚠️ Buff animation not available")

func get_focus_multiplier() -> float:
	# Return the current damage multiplier based on stacks
	if focus_stacks > 0:
		return focus_stacks * 2.0  # 1 stack = 2x, 2 stacks = 4x, etc.
	return 1.0  # No buff = normal damage

func consume_focus_buff():
	# Consume all focus stacks and hide animation
	if focus_stacks > 0:
		var multiplier = get_focus_multiplier()
		focus_stacks = 0
		print("🌟 Focus buff consumed! Applied " + str(multiplier) + "x damage multiplier")
		
		# Stop buff animation
		var animation_player = get_node_or_null("AnimationPlayer")
		if animation_player and animation_player.is_playing():
			animation_player.stop()
			print("🌟 Buff animation stopped")
		
		# Hide all buff sprites
		var buff1 = get_node_or_null("buff1")
		var buff2 = get_node_or_null("buff2")
		var buff3 = get_node_or_null("buff3")
		if buff1:
			buff1.visible = false
		if buff2:
			buff2.visible = false
		if buff3:
			buff3.visible = false
		print("🌟 All buff sprites hidden")
		
		return multiplier
	return 1.0

func trigger_muzzle_flash(attack_type: String = "normal") -> void:
	print("[Player2] trigger_muzzle_flash called with attack_type: " + attack_type + ", selected_ability: " + str(selected_ability))
	
	if not muzzle_flash:
		print("[Player2] No muzzle_flash node found!")
		return
	
	# Only trigger on Gun Girl's ranged attacks (big_shot, scatter_shot, or basic attack)
	if selected_ability != "big_shot" and selected_ability != "scatter_shot" and selected_ability != "attack" and selected_ability != "":
		print("[Player2] Not a ranged attack, skipping muzzle flash")
		return
	
	# Show flash
	muzzle_flash.visible = true
	print("[Player2] *** MUZZLE FLASH VISIBLE *** for " + str(selected_ability) + " at position " + str(muzzle_flash.position))
	
	# Clean up previous tween
	if muzzle_flash_tween:
		muzzle_flash_tween.kill()
	
	# Flash for 0.06 seconds then hide
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.tween_callback(_hide_muzzle_flash).set_delay(0.06)
	
	# Sound effects are now handled by TurnManager for basic attacks
	print("[Player2] Muzzle flash shown (TurnManager handles sound effects)")

func _hide_muzzle_flash() -> void:
	if muzzle_flash:
		muzzle_flash.visible = false

# Safe audio helper function - same as other managers
func _safe_audio_call(method_name: String, param: String = "") -> void:
	var audio_manager = get_node_or_null("/root/AudioManager")
	if not audio_manager:
		audio_manager = get_node_or_null("/root/BattleScene/AudioManager")
	
	if audio_manager and audio_manager.has_method(method_name):
		if param != "":
			audio_manager.call(method_name, param)
		else:
			audio_manager.call(method_name)
	else:
		var call_str = method_name + ("(" + param + ")" if param != "" else "()")
		print("[Player2] AudioManager." + call_str + " - stub (AudioManager not found)")

func _setup_new_idle_animation():
	print("[Player2] Setting up new idle animation")

	# Simply hide old sprites and show new one - with null checks
	var sprite2d = get_node_or_null("Sprite2D")
	var attack = get_node_or_null("attack")
	var block = get_node_or_null("p2-block")
	var dead = get_node_or_null("p2-dead")

	if is_instance_valid(sprite2d):
		sprite2d.visible = false
	if is_instance_valid(attack):
		attack.visible = false
	if is_instance_valid(block):
		block.visible = false
	if is_instance_valid(dead):
		dead.visible = false

	# Show new idle animation
	var idle_animated = get_node_or_null("IdleAnimatedSprite")
	if is_instance_valid(idle_animated):
		idle_animated.visible = true
		idle_animated.play("idle")

	# Disable old breathing system
	breathing_enabled = false

	print("[Player2] New idle animation should now be playing")

# ===== ANIMATION BRIDGE SYSTEM =====

# Configuration for bridge-based abilities
func get_bridge_ability_config(ability_name: String) -> Dictionary:
	match ability_name:
		"grenade":
			return {
				"uses_bridge": true,
				"qte_type": "confirm attack",
				"damage": 35
			}
		"bullet_rain":
			return {
				"uses_bridge": true,
				"qte_type": "confirm attack",
				"damage": 30
			}
		_:
			return {}

# Bridge-based animated ability executor
func execute_animated_ability(ability_name: String, target):
	var config = get_bridge_ability_config(ability_name)
	if config.is_empty():
		print("⚠️ No bridge config found for: ", ability_name)
		return
	
	print("🎬 [Player2] Starting bridge ability: ", ability_name)
	
	# Step 1: Spawn animation at player position
	var animation_instance = AnimationBridge.spawn_ability_animation(ability_name, global_position, self)
	if not animation_instance:
		print("❌ [Player2] Failed to spawn animation")
		return
	
	# Step 2: Play windup and wait for ready signal (skip for bullet_rain)
	if ability_name != "bullet_rain":
		AnimationBridge.play_windup_animation(ability_name)
		await AnimationBridge.animation_ready_for_qte
		print("🎯 [Player2] Windup complete, starting QTE")
	else:
		print("🎯 [Player2] Skipping windup for bullet_rain, starting QTE immediately")
	
	# Step 3: Run QTE
	var qte_manager = get_node_or_null("/root/QTEManager")
	if qte_manager and qte_manager.has_method("start_qte"):
		var qte_result = await qte_manager.start_qte(config.qte_type, 700, "Press Z!", target)
		print("🎯 [Player2] QTE result: ", qte_result)
		
		# Step 4: Apply damage if successful
		if qte_result in ["crit", "normal"] and target and target.has_method("take_damage"):
			var damage = config.damage
			if qte_result == "crit":
				damage *= 2
			apply_damage(target, damage)
			print("💥 [Player2] Applied ", damage, " damage")
		
		# Step 5: Play result animation and wait for completion
		AnimationBridge.play_result_animation(ability_name, qte_result)
		await AnimationBridge.animation_sequence_complete
		print("🎬 [Player2] Animation sequence complete")
	else:
		print("❌ [Player2] QTEManager not found")
		AnimationBridge.cleanup_animation(ability_name)

# ===== MODULAR STATUS ABILITIES =====

# 🧊 Freezing Shot - Skips enemy's next turn
func execute_freezing_shot_sequence(target):
	print("🧊 " + name + " begins Freezing Shot sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🧊 Freezing shot incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to freeze!")
	
	# Step 3: IMMEDIATE - Sound + Damage + Status Effect
	_play_freezing_shot_sound_effect(result)
	var total_damage = _apply_freezing_shot_immediate(target, result)
	
	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🧊 Freezing shot complete - damage already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 🛡️ Armor Piercing - Reduces enemy defense for multiple turns
func execute_armor_piercing_sequence(target):
	print("🛡️ " + name + " begins Armor Piercing sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🛡️ Armor piercing shot incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to pierce!")
	
	# Step 3: IMMEDIATE - Sound + Damage + Status Effect
	_play_armor_piercing_sound_effect(result)
	var total_damage = _apply_armor_piercing_immediate(target, result)
	
	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🛡️ Armor piercing complete - damage already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 🩸 Bleeding Shot - Applies damage over time
func execute_bleeding_shot_sequence(target):
	print("🩸 " + name + " begins Bleeding Shot sequence!")
	
	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte
	
	# Step 2: QTE
	print("🩸 Bleeding shot incoming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to bleed!")
	
	# Step 3: IMMEDIATE - Sound + Damage + Status Effect
	_play_bleeding_shot_sound_effect(result)
	var total_damage = _apply_bleeding_shot_immediate(target, result)
	
	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete
	
	print("🩸 Bleeding shot complete - damage already applied: ", total_damage)
	
	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# ===== IMMEDIATE DAMAGE & EFFECT HELPERS =====

func _apply_freezing_shot_immediate(target, qte_result: String) -> int:
	var total_damage = 0
	if qte_result in ["crit", "normal"]:
		total_damage = 12 if qte_result == "crit" else 8
		apply_damage(target, total_damage)
		VFXManager.play_enhanced_hit_effects(target, total_damage, VFXManager.EffectType.ICE)
		
		# Apply frozen effect to target
		var frozen_effect = {
			"type": "frozen",
			"target": target,
			"caster": self,
			"duration": 1,
			"skip_turn": true
		}
		target.status_effects.apply_effect(frozen_effect)
		print("🧊 IMMEDIATE: Applied frozen effect and " + str(total_damage) + " damage to ", target.name)
		
		# Show status applied popup with enhanced VFX
		CombatUI.show_status_applied_popup(target, "frozen")
		VFXManager.play_status_effect_vfx(target, "frozen", 2)  # Tier 2 with mini-zoom
	else:
		total_damage = 2
		apply_damage(target, total_damage)
		VFXManager.play_hit_effects(target)
		print("🧊 IMMEDIATE: Freezing shot failed - weak hit for ", total_damage, " damage")
	
	return total_damage

func _apply_armor_piercing_immediate(target, qte_result: String) -> int:
	var total_damage = 0
	if qte_result in ["crit", "normal"]:
		total_damage = 23 if qte_result == "crit" else 15
		apply_damage(target, total_damage)
		VFXManager.play_enhanced_hit_effects(target, total_damage, VFXManager.EffectType.CRITICAL)
		
		# Apply armor down effect to target
		var armor_effect = {
			"type": "armor_down",
			"target": target,
			"caster": self,
			"duration": 3,
			"damage_multiplier": 1.5
		}
		target.status_effects.apply_effect(armor_effect)
		print("🛡️ IMMEDIATE: Applied armor down and " + str(total_damage) + " damage to ", target.name)
		
		# Show status applied popup with enhanced VFX
		CombatUI.show_status_applied_popup(target, "armor_down")
		VFXManager.play_status_effect_vfx(target, "armor_down", 1)  # Tier 1 - just color flash
	else:
		total_damage = 5
		apply_damage(target, total_damage)
		VFXManager.play_hit_effects(target)
		print("🛡️ IMMEDIATE: Armor piercing failed - weak hit for ", total_damage, " damage")
	
	return total_damage

func _apply_bleeding_shot_immediate(target, qte_result: String) -> int:
	var total_damage = 0
	if qte_result in ["crit", "normal"]:
		total_damage = 15 if qte_result == "crit" else 10
		apply_damage(target, total_damage)
		VFXManager.play_enhanced_hit_effects(target, total_damage, VFXManager.EffectType.POISON)  # Use poison type for red/green
		
		# Apply bleed effect to target
		var bleed_effect = {
			"type": "bleed",
			"target": target,
			"caster": self,
			"stacks": 1,
			"duration": 4,
			"damage_per_stack": 10
		}
		target.status_effects.apply_effect(bleed_effect)
		print("🩸 IMMEDIATE: Applied bleed effect and " + str(total_damage) + " damage to ", target.name)
		
		# Show status applied popup with enhanced VFX
		CombatUI.show_status_applied_popup(target, "bleed")
		VFXManager.play_status_effect_vfx(target, "bleed", 1)  # Tier 1 - just color flash
	else:
		total_damage = 3
		apply_damage(target, total_damage)
		VFXManager.play_hit_effects(target)
		print("🩸 IMMEDIATE: Bleeding shot failed - weak hit for ", total_damage, " damage")
	
	return total_damage

# ===== SOUND EFFECT HELPERS =====

func _play_freezing_shot_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/gun1.wav")  # Different from regular gun sound
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func _play_armor_piercing_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/gun2.wav")  # Heavy gun sound
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func _play_bleeding_shot_sound_effect(qte_result: String):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return

	match qte_result:
		"crit":
			sfx_player.stream = preload("res://assets/sfx/crit.wav")
			sfx_player.play()
		"normal":
			sfx_player.stream = preload("res://assets/sfx/attack.wav")  # Regular attack sound
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

func _play_healing_touch_sound_effect(qte_result: String):
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

# Adding 5 new status effect abilities to Player2

# First, update the ability list


# ===== NEW STATUS EFFECT ABILITIES =====

# 😡 Berserker Rage - Applies rage status to self
func execute_berserker_rage_sequence(target):
	print("😡 " + name + " begins Berserker Rage sequence!")

	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("😡 Rage building...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z for RAGE!")

	# Step 3: IMMEDIATE - Apply rage status effect to self
	var total_damage = _apply_berserker_rage_immediate(self, result)

	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("😡 Berserker rage complete - effect applied")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 💚 Healing Touch - Applies regeneration to self
func execute_healing_touch_sequence(target):
	print("💚 " + name + " begins Healing Touch sequence!")

	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("💚 Channeling healing energy...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to heal!")

	# Step 3: IMMEDIATE - Sound + Apply regeneration status effect to self
	_play_healing_touch_sound_effect(result)
	var total_damage = _apply_healing_touch_immediate(self, result)

	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("💚 Healing touch complete - effect applied")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 💀 Curse Strike - Applies weakness to enemy
func execute_curse_strike_sequence(target):
	print("💀 " + name + " begins Curse Strike sequence!")

	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("💀 Dark curse forming...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to curse!")

	# Step 3: IMMEDIATE - Apply weakness status effect to enemy
	var total_damage = _apply_curse_strike_immediate(target, result)

	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("💀 Curse strike complete - effect applied")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# ⚡ Time Shift - Applies haste to self
func execute_time_shift_sequence(target):
	print("⚡ " + name + " begins Time Shift sequence!")

	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("⚡ Manipulating time flow...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z for SPEED!")

	# Step 3: IMMEDIATE - Apply haste status effect to self
	var total_damage = _apply_time_shift_immediate(self, result)

	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("⚡ Time shift complete - effect applied")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# 🛡️ Energy Barrier - Applies barrier to self
func execute_energy_barrier_sequence(target):
	print("🛡️ " + name + " begins Energy Barrier sequence!")

	# Step 1: Spawn and play windup animation (uses basic_attack placeholder)
	var instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, self)
	AnimationBridge.play_windup_animation("basic_attack")
	await AnimationBridge.animation_ready_for_qte

	# Step 2: QTE
	print("🛡️ Forming protective barrier...")
	var result = await QTEManager.start_qte("confirm attack", 600, "Press Z to shield!")

	# Step 3: IMMEDIATE - Apply barrier status effect to self
	var total_damage = _apply_energy_barrier_immediate(self, result)

	# Step 4: Play result animation (pure visual feedback)
	AnimationBridge.play_result_animation("basic_attack", result)
	await AnimationBridge.animation_sequence_complete

	print("🛡️ Energy barrier complete - effect applied")

	return {
		"damage": total_damage,
		"qte_result": result,
		"success": true,
		"handled_damage": true
	}

# ===== NEW STATUS EFFECT HELPERS =====

func _apply_berserker_rage_immediate(caster, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var rage_effect = {
			"type": "rage",
			"target": caster,
			"caster": caster,
			"duration": 2,
			"damage_multiplier": 2.0
		}
		caster.status_effects.apply_effect(rage_effect)
		print("😡 IMMEDIATE: Applied rage effect to ", caster.name)

		# Show status applied popup
		CombatUI.show_status_applied_popup(caster, "rage")
		VFXManager.play_status_effect_vfx(caster, "rage", 1)
	else:
		print("😡 IMMEDIATE: Berserker rage failed - no effect")

	return 0  # No damage, only status effect

func _apply_healing_touch_immediate(caster, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var regen_effect = {
			"type": "regeneration",
			"target": caster,
			"caster": caster,
			"duration": 3,
			"heal_per_turn": 15
		}
		caster.status_effects.apply_effect(regen_effect)
		print("💚 IMMEDIATE: Applied regeneration effect to ", caster.name)

		# Show status applied popup
		CombatUI.show_status_applied_popup(caster, "regeneration")
		VFXManager.play_status_effect_vfx(caster, "regeneration", 1)
	else:
		print("💚 IMMEDIATE: Healing touch failed - no effect")

	return 0  # No damage, only status effect

func _apply_curse_strike_immediate(target, qte_result: String) -> int:
	var total_damage = 0
	if qte_result in ["crit", "normal"]:
		# Minor damage
		total_damage = 8 if qte_result == "crit" else 5
		apply_damage(target, total_damage)

		# Apply weakness effect
		var weakness_effect = {
			"type": "weakness",
			"target": target,
			"caster": self,
			"duration": 3,
			"damage_multiplier": 1.5
		}
		target.status_effects.apply_effect(weakness_effect)
		print("💀 IMMEDIATE: Applied weakness effect and " + str(total_damage) + " damage to ", target.name)

		# Show status applied popup
		CombatUI.show_status_applied_popup(target, "weakness")
		VFXManager.play_status_effect_vfx(target, "weakness", 1)
	else:
		total_damage = 2
		apply_damage(target, total_damage)
		print("💀 IMMEDIATE: Curse strike failed - weak hit for ", total_damage, " damage")

	return total_damage

func _apply_time_shift_immediate(caster, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var haste_effect = {
			"type": "haste",
			"target": caster,
			"caster": caster,
			"duration": 2
		}
		caster.status_effects.apply_effect(haste_effect)
		print("⚡ IMMEDIATE: Applied haste effect to ", caster.name)

		# Show status applied popup
		CombatUI.show_status_applied_popup(caster, "haste")
		VFXManager.play_status_effect_vfx(caster, "haste", 1)
	else:
		print("⚡ IMMEDIATE: Time shift failed - no effect")

	return 0  # No damage, only status effect

func _apply_energy_barrier_immediate(caster, qte_result: String) -> int:
	if qte_result in ["crit", "normal"]:
		var absorb_amount = 40 if qte_result == "crit" else 30
		var barrier_effect = {
			"type": "barrier",
			"target": caster,
			"caster": caster,
			"absorb_amount": absorb_amount
		}
		caster.status_effects.apply_effect(barrier_effect)
		print("🛡️ IMMEDIATE: Applied barrier effect (" + str(absorb_amount) + " absorb) to ", caster.name)

		# Show status applied popup
		CombatUI.show_status_applied_popup(caster, "barrier")
		VFXManager.play_status_effect_vfx(caster, "barrier", 1)
	else:
		print("🛡️ IMMEDIATE: Energy barrier failed - no effect")

	return 0  # No damage, only status effect

# Save/Load methods for SaveManager
func get_current_hp() -> int:
	return hp

func set_hp(new_hp: int):
	hp = clamp(new_hp, 0, hp_max)
	print("[Player2] HP set to: ", hp, "/", hp_max)

func get_resolve() -> int:
	return ResolveManager.player2_resolve

func set_resolve(new_resolve: int):
	ResolveManager.player2_resolve = clamp(new_resolve, 0, ResolveManager.MAX_RESOLVE)
	print("[Player2] Resolve set to: ", ResolveManager.player2_resolve)

# ===== ITEM SYSTEM =====

func heal(amount: int):
	"""Heal the player by the specified amount"""
	if is_defeated:
		return

	var old_hp = hp
	hp = clamp(hp + amount, 0, hp_max)
	var actual_heal = hp - old_hp

	print("[Player2] Healed for ", actual_heal, " HP (", old_hp, " → ", hp, ")")
	CombatUI.update_hp_bar("Player2", hp, hp_max)

	if actual_heal > 0:
		CombatUI.show_damage_popup(self, -actual_heal)  # Negative damage = healing

func use_bandages():
	"""Apply regeneration effect (heal 15 HP/turn for 3 turns)"""
	var regen_effect = {
		"type": "regeneration",
		"target": self,
		"caster": self,
		"duration": 3,
		"heal_per_turn": 15
	}
	status_effects.apply_effect(regen_effect)
	print("🩹 [Player2] Used Bandages - regeneration applied")

	# Show status applied popup
	CombatUI.show_status_applied_popup(self, "regeneration")
	VFXManager.play_status_effect_vfx(self, "regeneration", 1)

func use_health_potion():
	"""Instantly restore 50 HP"""
	heal(50)
	print("💊 [Player2] Used Health Potion")

func use_resolve_potion():
	"""Restore 2 Resolve points"""
	ResolveManager.add_resolve("Player2", 2)
	print("🔋 [Player2] Used Resolve Potion")

func use_phoenix_feather():
	"""Grant one-time revival protection"""
	has_phoenix_feather = true

	# Apply phoenix feather status effect for visual display
	var phoenix_effect = {
		"type": "phoenix_feather",
		"target": self,
		"caster": self,
		"duration": 99  # Lasts until consumed
	}
	status_effects.apply_effect(phoenix_effect)
	print("🔥 [Player2] Used Phoenix Feather - revival protection active")

	# Show status applied popup
	CombatUI.show_status_applied_popup(self, "phoenix_feather")
	VFXManager.play_status_effect_vfx(self, "phoenix_feather", 1)

func use_rage_potion():
	"""Apply rage status effect (+100% damage, +25% incoming damage)"""
	var rage_effect = {
		"type": "rage",
		"target": self,
		"caster": self,
		"duration": 3  # 3 turns
	}
	status_effects.apply_effect(rage_effect)
	print("😡 [Player2] Used Rage Potion - rage status applied")

	# Show status applied popup
	CombatUI.show_status_applied_popup(self, "rage")
	VFXManager.play_status_effect_vfx(self, "rage", 1)

func use_speed_boost():
	"""Apply haste status effect (act twice per turn)"""
	var haste_effect = {
		"type": "haste",
		"target": self,
		"caster": self,
		"duration": 2  # 2 turns
	}
	status_effects.apply_effect(haste_effect)
	print("⚡ [Player2] Used Speed Boost - haste status applied")

	# Show status applied popup
	CombatUI.show_status_applied_popup(self, "haste")
	VFXManager.play_status_effect_vfx(self, "haste", 1)

func use_pain_killer():
	"""Apply damage immunity for next hit"""
	var immunity_effect = {
		"type": "pain_killer",
		"target": self,
		"caster": self,
		"duration": 1,  # Only lasts 1 turn but removed on damage
		"absorb_amount": 999  # Absorbs all damage
	}
	status_effects.apply_effect(immunity_effect)
	print("🛡️ [Player2] Used Pain Killer - damage immunity active")

	# Show status applied popup
	CombatUI.show_status_applied_popup(self, "pain_killer")
	VFXManager.play_status_effect_vfx(self, "pain_killer", 1)
