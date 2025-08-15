extends Node2D

var hp_max: int = 50
var hp: int = 50
var is_defeated: bool = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	add_to_group("players")
	ScreenShake.shake(5.0, 0.3)

func start_turn():
	if is_defeated:
		print(name, "is defeated and skips turn.")
		get_node("/root/BattleScene/TurnManager").end_turn()
		return
	print(name, "is ready to act.")

func show_block_animation():
	# Get references to both sprites
	var main_sprite = $Sprite2D
	var block_sprite = $"p1-block"  # Use quotes for the dash
	
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
	$"p1-block".visible = false
	
	# Show death sprite
	$"p1-dead".visible = true
	print("DEATH→ " + name + " death sprite displayed")

func hide_death_sprite():
	# Hide death sprite and restore main sprite
	$"p1-dead".visible = false
	$Sprite2D.visible = true
	$"p1-block".visible = false
	print("REVIVE→ " + name + " restored to life")

func attack(target):
	if target == null:
		print(name, "tried to attack a NULL target!")
		return
	var damage = rng.randi_range(5, 10)
	print(name, "attacks", target.name, "for", damage, "damage")
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

	CombatUI.update_hp_bar("Player1", hp, hp_max)  # Use hp_max instead of 100

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
	return ["2x_cut", "moonfall_slash", "spirit_wave"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"2x_cut":
			return "2x Cut"
		"moonfall_slash":
			return "Moonfall Slash"
		"spirit_wave":
			return "Spirit Wave"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🎯 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Call QTEManager to start the QTE for this ability
	await QTEManager.start_qte_for_ability(self, ability_name, target)

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
		"2x_cut":
			match result:
				"crit":
					print("⚔️ " + name + " executes a PERFECT 2x Cut! Triple echo!")
					# 3 hits of 10 damage each
					for i in range(3):
						damage = 10
						print("  → Blade echo " + str(i+1) + " slashes for " + str(damage) + " damage!")
						VFXManager.play_hit_effects(target)
						target.take_damage(damage)
						await get_tree().create_timer(0.2).timeout
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					print("⚔️ " + name + " performs 2x Cut! Double strike!")
					# 2 hits of 7 damage each
					for i in range(2):
						damage = 7
						print("  → Blade strike " + str(i+1) + " cuts for " + str(damage) + " damage!")
						VFXManager.play_hit_effects(target)
						target.take_damage(damage)
						await get_tree().create_timer(0.2).timeout
					sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
				"fail":
					print("💫 " + name + " mistimes the 2x Cut! Only one strike lands...")
					damage = 5
					print("  → Single blade grazes for " + str(damage) + " damage.")
					VFXManager.play_hit_effects(target)
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
		"moonfall_slash":
			match result:
				"crit":
					damage = 25
					print("🌙 " + name + " channels a PERFECT Moonfall Slash! Celestial resonance!")
					print("  → Moonlit blade devastates for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
				"normal":
					damage = 15
					print("🌙 " + name + " executes Moonfall Slash!")
					print("  → Lunar strike cuts for " + str(damage) + " damage!")
					target.take_damage(damage)
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
				"fail":
					damage = 0
					print("💫 " + name + " loses lunar connection! Complete miss!")
					print("  → Blade misses the echo... No damage!")
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
		
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
