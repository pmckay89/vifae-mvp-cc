extends Node2D

var hp_max: int = 100
var hp: int = 50
var is_defeated: bool = false
var selected_ability = ""

@onready var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	add_to_group("players")
	
	# Hide main sprite - only use idle animation for breathing
	$Sprite2D.visible = false
	
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
	return ["2x_cut", "moonfall_slash", "spirit_wave", "uppercut"]

func get_ability_display_name(ability_name: String) -> String:
	match ability_name:
		"2x_cut":
			return "2x Cut"
		"moonfall_slash":
			return "Moonfall Slash"
		"spirit_wave":
			return "Spirit Wave"
		"uppercut":
			return "Uppercut"
		_:
			return ability_name

func execute_ability(ability_name: String, target):
	selected_ability = ability_name
	print("🎯 " + name + " prepares " + get_ability_display_name(ability_name) + "!")
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	# Handle special abilities with custom animations
	if ability_name == "2x_cut":
		await execute_2x_cut_dual_qte(target)
	elif ability_name == "uppercut":
		await execute_uppercut_sequence(target)
	else:
		# Call QTEManager to start the QTE for this ability
		await QTEManager.start_qte_for_ability(self, ability_name, target)

func execute_2x_cut_dual_qte(target):
	print("⚔️ " + name + " begins ninja 2x Cut sequence!")
	
	# Get references to animation nodes
	var idle_animation = get_node_or_null("idle")
	var combat_animation = get_node_or_null("CombatAnimations")
	
	if not combat_animation:
		print("❌ CombatAnimations node not found!")
		return
	
	# Step 1: Move sprite right toward enemy
	var original_pos = global_position
	var attack_pos = Vector2(original_pos.x + 80, original_pos.y)
	
	# Hide idle animation
	if idle_animation:
		idle_animation.visible = false
	
	# Show combat animation node and move right  
	combat_animation.visible = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", attack_pos, 0.3)
	await tween.finished
	
	# Step 2: Play 2x wind-up animation
	print("⚔️ 2x Wind-up phase...")
	combat_animation.play("2xwindup")
	await get_tree().create_timer(0.7).timeout  # 7 frames at 10 fps = 0.7 seconds
	
	# Step 3: First QTE
	print("⚔️ First strike incoming...")
	var result1 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 1st Cut!")
	
	# Brief pause between QTEs so player can see the second one
	await get_tree().create_timer(0.3).timeout
	
	# Step 4: Second QTE
	print("⚔️ Second strike incoming...")
	var result2 = await QTEManager.start_qte("confirm attack", 500, "Press Z for 2nd Cut!")
	
	# Step 5: After both QTEs, play 2x attack animation
	print("⚔️ Unleashing 2x Cut!")
	combat_animation.play("2x")
	await get_tree().create_timer(0.71).timeout
	
	# Process both results
	process_2x_cut_result(result1, target, 1)
	process_2x_cut_result(result2, target, 2)
	
	# Step 6: Play jumpback animation
	print("⚔️ Jumping back...")
	combat_animation.play("jumpback")
	await get_tree().create_timer(0.7).timeout
	
	# Step 7: Return to original position and restore idle
	tween = create_tween()
	tween.tween_property(self, "global_position", original_pos, 0.3)
	await tween.finished
	
	# Hide combat animations and restore idle breathing
	combat_animation.visible = false
	combat_animation.stop()
	
	if idle_animation:
		idle_animation.visible = true
		idle_animation.play("idle")
	
	print("⚔️ Ninja 2x Cut sequence complete!")

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
