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
	
	# Handle special dual QTE for 2x Cut
	if ability_name == "2x_cut":
		await execute_2x_cut_dual_qte(target)
	else:
		# Call QTEManager to start the QTE for this ability
		await QTEManager.start_qte_for_ability(self, ability_name, target)

func execute_2x_cut_dual_qte(target):
	print("⚔️ " + name + " begins 2x Cut sequence!")
	
	# First QTE
	print("⚔️ First strike incoming...")
	var result1 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 1st Cut!")
	process_2x_cut_result(result1, target, 1)
	
	# Brief pause between strikes
	await get_tree().create_timer(0.2).timeout
	
	# Second QTE  
	print("⚔️ Second strike incoming...")
	var result2 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 2nd Cut!")
	process_2x_cut_result(result2, target, 2)
	
	print("⚔️ 2x Cut sequence complete!")

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
			# This is handled by rapid-press QTE now - result contains hit count
			var hit_count = int(result)
			var total_damage = hit_count * 5
			print("🌙 " + name + " unleashes Moonfall Slash barrage!")
			print("  → " + str(hit_count) + " rapid strikes for " + str(total_damage) + " total damage!")
			
			if hit_count > 0:
				# Apply damage all at once for now, could add animation later
				VFXManager.play_hit_effects(target)
				target.take_damage(total_damage)
			else:
				print("  → No strikes connected...")
		
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
