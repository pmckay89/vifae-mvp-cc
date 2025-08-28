extends Node2D

var hp_max: int = 100
var hp: int = 100
var is_defeated = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()

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
	_setup_muzzle_flash()
	_ensure_buff_animation_hidden()
	_setup_new_idle_animation()

func start_turn():
	if is_defeated:
		print(name, "is defeated and skips turn.")
		get_node("/root/BattleScene/TurnManager").end_turn()
		return
	print(name, "is ready to act.")

func show_block_animation(duration: float = 1.0):
	# Pause breathing during block animation
	var was_breathing = breathing_enabled
	stop_breathing_animation()
	
	# Get references to all sprites
	var main_sprite = $Sprite2D
	var idle2_sprite = $idle2
	var attack_sprite = $attack
	var block_sprite = $"p2-block"  # Use quotes for the dash
	
	# Hide all other sprites and show block sprite
	main_sprite.visible = false
	idle2_sprite.visible = false
	attack_sprite.visible = false
	block_sprite.visible = true
	
	# Hold for specified duration
	await get_tree().create_timer(duration).timeout
	
	# Switch back to main sprite and hide block sprite
	block_sprite.visible = false
	main_sprite.visible = true
	idle2_sprite.visible = false
	attack_sprite.visible = false
	
	# Resume breathing if it was enabled
	if was_breathing:
		resume_breathing_animation()

func show_death_sprite():
	# Stop breathing when dead
	stop_breathing_animation()
	
	# Hide all other sprites
	$Sprite2D.visible = false
	$idle2.visible = false
	$attack.visible = false
	$"p2-block".visible = false
	
	# Show death sprite
	$"p2-dead".visible = true
	print("DEATH→ " + name + " death sprite displayed")

func hide_death_sprite():
	# Hide death sprite and restore main sprite
	$"p2-dead".visible = false
	$Sprite2D.visible = true
	$idle2.visible = false
	$attack.visible = false
	$"p2-block".visible = false
	
	# Resume breathing when revived
	resume_breathing_animation()
	print("REVIVE→ " + name + " restored to life")

func show_attack_windup():
	# Show windup pose during QTE - stop breathing and show attack sprite
	stop_breathing_animation()
	
	# Hide all idle sprites and show attack sprite (p2.png windup pose)
	var main_sprite = $Sprite2D
	var idle2_sprite = $idle2
	var attack_sprite = $attack
	
	main_sprite.visible = false
	idle2_sprite.visible = false
	attack_sprite.visible = true
	
	print("[Player2] Showing attack windup pose (p2.png)")

func hide_attack_windup():
	# Hide attack sprite and return to breathing animation
	var attack_sprite = $attack
	attack_sprite.visible = false
	
	resume_breathing_animation()
	print("[Player2] Hiding attack windup pose, resuming breathing")

# STANDARDIZED ATTACK SYSTEM - Player2 Implementation
func start_attack_windup():
	print("🔫 " + name + " starting attack windup")
	show_attack_windup()
	# Small delay for windup animation
	await get_tree().create_timer(0.3).timeout
	print("🔫 Windup complete, ready for QTE!")

func finish_attack_sequence(qte_result: String, target):
	print("🔫 " + name + " finishing attack with result: " + qte_result)
	
	# Brief pause for attack timing
	await get_tree().create_timer(0.2).timeout
	
	# Hide attack pose
	hide_attack_windup()
	
	print("🔫 Gun Girl attack sequence complete!")

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
	target.take_damage(damage)
	
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
	target.take_damage(damage)
	
	# Hide windup pose after attack
	hide_attack_windup()

func take_damage(amount):
	if is_defeated:
		return

	hp -= amount
	print(name, "takes", amount, "damage. HP:", hp)

	CombatUI.update_hp_bar("Player2", hp, hp_max)  # Use hp_max instead of 100

	if hp <= 0:
		hp = 0
		is_defeated = true
		print(name, "has been defeated!")
		show_death_sprite()

	CombatUI.show_damage_popup(self, amount)

func reset_for_new_combat():
	# Called by TurnManager when combat resets
	hp = hp_max
	is_defeated = false
	hide_death_sprite()
	
	# Ensure breathing is active after reset
	resume_breathing_animation()
	print("RESET→ " + name + " fully restored")

func get_ability_list() -> Array:
	return ["big_shot", "scatter_shot", "focus", "grenade", "bullet_rain"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"big_shot":
			return "Big Shot"
		"scatter_shot":
			return "Scatter Shot"
		"focus":
			return "Focus"
		"grenade":
			return "Grenade"
		"bullet_rain":
			return "Bullet Rain"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🔫 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	# Handle focus ability without QTE
	if ability_name == "focus":
		await get_tree().create_timer(0.5).timeout
		activate_focus()
		return
	
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
					target.take_damage(damage)
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
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"fail":
					damage = 8
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("💨 " + name + " rushes the Big Shot...")
					print("  → Hasty shot grazes for " + str(damage) + " damage.")
					target.take_damage(damage)
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
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
				"fail":
					damage = 6
					# Apply focus buff multiplier
					var multiplier = consume_focus_buff()
					damage = int(damage * multiplier)
					print("💨 " + name + " fails to complete the Scatter Shot sequence...")
					print("  → Incomplete spread reduces damage to " + str(damage) + ".")
					target.take_damage(damage)
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
	
	if main_sprite and idle2_sprite:
		main_sprite.visible = false
		idle2_sprite.visible = true
		main_sprite_visible = false

func _swap_to_main() -> void:
	if not breathing_enabled:
		return
		
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")
	
	if main_sprite and idle2_sprite:
		main_sprite.visible = true
		idle2_sprite.visible = false
		main_sprite_visible = true

func stop_breathing_animation() -> void:
	breathing_enabled = false
	if breathing_tween:
		breathing_tween.kill()
		breathing_tween = null
	
	# Reset to main sprite visible
	var main_sprite = get_node_or_null("Sprite2D")
	var idle2_sprite = get_node_or_null("idle2")
	
	if main_sprite and idle2_sprite:
		main_sprite.visible = true
		idle2_sprite.visible = false
		main_sprite_visible = true
	
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
	
	# Simply hide old sprites and show new one
	$Sprite2D.visible = false
	$idle2.visible = false
	$attack.visible = false
	$"p2-block".visible = false
	$"p2-dead".visible = false
	
	# Show new idle animation
	var idle_animated = $IdleAnimatedSprite
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
			target.take_damage(damage)
			print("💥 [Player2] Applied ", damage, " damage")
		
		# Step 5: Play result animation and wait for completion
		AnimationBridge.play_result_animation(ability_name, qte_result)
		await AnimationBridge.animation_sequence_complete
		print("🎬 [Player2] Animation sequence complete")
	else:
		print("❌ [Player2] QTEManager not found")
		AnimationBridge.cleanup_animation(ability_name)
