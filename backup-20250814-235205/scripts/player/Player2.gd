extends Node2D

var hp_max: int = 50
var hp: int = 50
var is_defeated = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	add_to_group("players")

func start_turn():
	if is_defeated:
		print(name, "is defeated and skips turn.")
		get_node("/root/BattleScene/TurnManager").end_turn()
		return
	print(name, "is ready to act.")

func show_block_animation():
	# Get references to both sprites
	var main_sprite = $Sprite2D
	var block_sprite = $"p2-block"  # Use quotes for the dash
	
	# Switch to block sprite
	main_sprite.visible = false
	block_sprite.visible = true
	
	# Hold for 1 second
	await get_tree().create_timer(1.0).timeout
	
	# Switch back to main sprite
	block_sprite.visible = false
	main_sprite.visible = true

func show_death_sprite():
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
	print("REVIVE→ " + name + " restored to life")

func attack(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	var damage = rng.randi_range(5, 10)
	print(name, "attacks", target.name, "for", damage, "damage")
	
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
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
				"normal":
					damage = 25
					print("🔫 " + name + " lands a solid Big Shot!")
					print("  → Heavy shot hits for " + str(damage) + " damage!")
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
