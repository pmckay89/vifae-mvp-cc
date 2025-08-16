extends Node2D

var hp_max: int = 50
var hp: int = 50
var is_defeated = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()

# Breathing animation variables
var breathing_tween: Tween
var original_scale: Vector2
var original_position: Vector2
var breath_scale_y: float = 1.0
var breathing_enabled: bool = true

# Muzzle flash variables
var muzzle_flash: ColorRect
var muzzle_flash_tween: Tween

func _ready():
	rng.randomize()
	add_to_group("players")
	_setup_muzzle_flash()
	_start_breathing_animation()

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
	
	# Get references to both sprites
	var main_sprite = $Sprite2D
	var block_sprite = $"p2-block"  # Use quotes for the dash
	
	# Switch to block sprite
	main_sprite.visible = false
	block_sprite.visible = true
	
	# Hold for specified duration
	await get_tree().create_timer(duration).timeout
	
	# Switch back to main sprite
	block_sprite.visible = false
	main_sprite.visible = true
	
	# Resume breathing if it was enabled
	if was_breathing:
		resume_breathing_animation()

func show_death_sprite():
	# Stop breathing when dead
	stop_breathing_animation()
	
	# Hide all other sprites
	$Sprite2D.visible = false
	$"p2-block".visible = false
	
	# Show death sprite
	$"p2-dead".visible = true
	print("DEATH→ " + name + " death sprite displayed")

func hide_death_sprite():
	# Hide death sprite and restore main sprite
	$"p2-dead".visible = false
	$Sprite2D.visible = true
	$"p2-block".visible = false
	
	# Resume breathing when revived
	resume_breathing_animation()
	print("REVIVE→ " + name + " restored to life")

func attack(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	var damage = rng.randi_range(5, 10)
	print(name, "attacks", target.name, "for", damage, "damage")
	
	# Trigger muzzle flash for Gun Girl's basic attacks
	trigger_muzzle_flash("normal")
	
	# Add gun sound effect for Gun Girl
	var sfx_player = get_node("/root/BattleScene/SFXPlayer")
	sfx_player.stream = preload("res://assets/sfx/gun1.wav")
	sfx_player.play()
	
	VFXManager.play_hit_effects(target)
	target.take_damage(damage)

func attack_critical(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	var damage = rng.randi_range(15, 25)
	print(name, "CRITICAL ATTACK on", target.name, "for", damage, "damage!")
	
	# Trigger muzzle flash for Gun Girl's critical attacks
	trigger_muzzle_flash("crit")
	
	VFXManager.play_hit_effects(target)
	target.take_damage(damage)

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
	return ["big_shot", "scatter_shot"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"big_shot":
			return "Big Shot"
		"scatter_shot":
			return "Scatter Shot"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🔫 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Call QTEManager to start the QTE for this ability
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
					print("🎯 " + name + " executes a PERFECT Big Shot! Sniper's dream!")
					print("  → Precision shot devastates for " + str(damage) + " damage!")
					trigger_muzzle_flash("crit")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"normal":
					damage = 25
					print("🔫 " + name + " lands a solid Big Shot!")
					print("  → Heavy shot hits for " + str(damage) + " damage!")
					trigger_muzzle_flash("normal")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"fail":
					damage = 8
					print("💨 " + name + " rushes the Big Shot...")
					print("  → Hasty shot grazes for " + str(damage) + " damage.")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		"scatter_shot":
			match result:
				"crit", "normal":
					damage = 35
					print("💥 " + name + " completes the Scatter Shot sequence! All targets hit!")
					print("  → Devastating spread attack deals " + str(damage) + " damage!")
					trigger_muzzle_flash("normal")  # Use normal for both crit and normal scatter shot
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
				"fail":
					damage = 6
					print("💨 " + name + " fails to complete the Scatter Shot sequence...")
					print("  → Incomplete spread reduces damage to " + str(damage) + ".")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		_:
			print("⚠️ Unknown ability: " + selected_ability)

# Breathing Animation System - Safe and Independent
func _start_breathing_animation() -> void:
	if not breathing_enabled:
		return
		
	# Get main sprite for animation (safe checks)
	var main_sprite = get_node_or_null("Sprite2D")
	if not main_sprite:
		print("[Player2] No Sprite2D found for breathing animation - skipping")
		return
	
	# Store original transform values
	original_scale = main_sprite.scale
	original_position = main_sprite.position
	
	# Start breathing loop
	_breathing_loop()
	print("[Player2] Breathing animation started")

func _breathing_loop() -> void:
	if not breathing_enabled:
		return
		
	var main_sprite = get_node_or_null("Sprite2D")
	if not main_sprite:
		return
	
	# Clean up previous tween if it exists
	if breathing_tween:
		breathing_tween.kill()
	
	# Create new breathing tween with simple back-and-forth motion
	breathing_tween = create_tween()
	breathing_tween.set_loops()  # Infinite loop
	
	# Simple breathing: normal -> expand -> normal -> contract -> repeat
	var breath_duration = 1.5
	
	# Expand phase
	breathing_tween.tween_method(_update_breathing, 1.0, 1.02, breath_duration / 4)
	# Contract phase  
	breathing_tween.tween_method(_update_breathing, 1.02, 0.98, breath_duration / 2)
	# Return to normal
	breathing_tween.tween_method(_update_breathing, 0.98, 1.0, breath_duration / 4)

func _update_breathing(scale_factor: float) -> void:
	if not breathing_enabled:
		return
		
	var main_sprite = get_node_or_null("Sprite2D")
	if not main_sprite:
		return
	
	# Apply gentle scale breathing (Y-axis only)
	breath_scale_y = scale_factor
	main_sprite.scale = Vector2(original_scale.x, original_scale.y * breath_scale_y)
	
	# Optional gentle 2px vertical bob
	var bob_offset = (scale_factor - 1.0) * -2.0  # Inverted so expansion moves up slightly
	main_sprite.position = Vector2(original_position.x, original_position.y + bob_offset)

func stop_breathing_animation() -> void:
	breathing_enabled = false
	if breathing_tween:
		breathing_tween.kill()
		breathing_tween = null
	
	# Reset to original transform
	var main_sprite = get_node_or_null("Sprite2D")
	if main_sprite:
		main_sprite.scale = original_scale
		main_sprite.position = original_position
	
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
	
	# Trigger hit sound through safe audio system
	_safe_audio_call("play_hit", attack_type)

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
