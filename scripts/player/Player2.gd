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
	return ["scythe_spin", "lance_pierce", "spirit_slash"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"scythe_spin":
			return "Scythe Spin"
		"lance_pierce":
			return "Lance Pierce"
		"spirit_slash":
			return "Spirit Slash"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("⚔️ " + name + " channels " + get_ability_display_name(ability_name) + "!")
	
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
		"scythe_spin":
			match result:
				"crit":
					print("🌪️ " + name + " executes a PERFECT Scythe Spin! Triple strike!")
					print("  ✨ Faerie enhances the blade with magic!")
					# 3 hits of 9 damage each
					for i in range(3):
						damage = 9
						print("  → Spinning slash " + str(i+1) + " cuts for " + str(damage) + " damage!")
						VFXManager.play_hit_effects(target)
						target.take_damage(damage)
						await get_tree().create_timer(0.2).timeout
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					print("⚔️ " + name + " performs Scythe Spin! Double strike!")
					# 2 hits of 6 damage each
					for i in range(2):
						damage = 6
						print("  → Spinning slash " + str(i+1) + " hits for " + str(damage) + " damage!")
						VFXManager.play_hit_effects(target)
						target.take_damage(damage)
						await get_tree().create_timer(0.2).timeout
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
				"fail":
					print("💫 " + name + " loses balance during Scythe Spin!")
					damage = 4
					print("  → Weak slash grazes for " + str(damage) + " damage.")
					VFXManager.play_hit_effects(target)
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		"lance_pierce":
			match result:
				"crit":
					damage = 25
					print("⚡ " + name + " delivers a DEVASTATING Lance Pierce!")
					print("  ✨ Faerie guides the blade to the enemy's weak point!")
					print("  → Piercing thrust impales for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					damage = 18
					print("🗡️ " + name + " thrusts with Lance Pierce!")
					print("  → Clean strike pierces for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
				"fail":
					damage = 10
					print("⚠️ " + name + " telegraphs the Lance Pierce!")
					print("  → Partially blocked thrust deals " + str(damage) + " damage.")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		"spirit_slash":
			match result:
				"crit":
					damage = 28
					print("🌟 " + name + " unleashes a TRANSCENDENT Spirit Slash!")
					print("  ✨ Faerie merges with the blade! Pure energy erupts!")
					print("  → Ethereal slash devastates for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					damage = 20
					print("✨ " + name + " channels Spirit Slash!")
					print("  → Magical blade cuts for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
				"fail":
					print("💥 " + name + " loses control of Spirit Slash! The energy backfires!")
					print("  ⚠️ Faerie shrieks as dark magic rebounds!")
					damage = 10
					print("  → " + name + " takes " + str(damage) + " self-damage from the backlash!")
					self.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
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
		
		_:
			print("⚠️ Unknown ability: " + selected_ability)
