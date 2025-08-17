extends Node2D

# Enemy stats only - no turn management
var hp_max: int = 150
var hp: int = hp_max
var is_defeated: bool = false
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()

# This is called by the new TurnManager system for enemy attack animations
func attack_animation(target: Node, attack_type: String = "", play_sound: bool = true) -> void:
	print("🔥 ENEMY ATTACK ANIMATION - target:", target.name, "attack:", attack_type)
	if is_defeated:
		return

	# Show enemy attack sprite based on target
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	var enemy_idle_sprite = get_node_or_null("Sprite2D")  # Default enemy sprite
	
	print("🔧 e-block1 exists:", e_block1 != null)
	print("🔧 e-block2 exists:", e_block2 != null)
	print("🔧 enemy idle sprite exists:", enemy_idle_sprite != null)
	
	# Hide default enemy sprite during attack
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = false
	
	if target.name == "Player1" and e_block1:
		e_block1.visible = true
		print("🎬 Showing enemy attack animation for Player1")
	elif target.name == "Player2" and e_block2:
		e_block2.visible = true
		print("🎬 Showing enemy attack animation for Player2")
	else:
		print("❌ No attack sprite found for target:", target.name)

	# Play attack-specific sound only if requested
	if play_sound:
		var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
		if sfx_player:
			match attack_type:
				"phase_slam":
					# Phase slam sound is played earlier in TurnManager, don't duplicate
					print("🎵 Phase Slam sound already playing from TurnManager")
				_:
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()

# This hides the attack sprites and shows the idle sprite again
func end_attack_animation() -> void:
	print("🎬 Enemy attack animation finished")
	
	# Hide enemy attack sprites
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	var enemy_idle_sprite = get_node_or_null("Sprite2D")
	
	if e_block1:
		e_block1.visible = false
	if e_block2:
		e_block2.visible = false
	
	# Show default enemy sprite again
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = true

# ORIGINAL ATTACK METHOD - Kept for compatibility
func attack(target: Node) -> void:
	print("🔥 ENEMY ATTACK STARTED - target:", target.name)
	if is_defeated:
		return

	var dmg := rng.randi_range(6, 12)
	print(name, "attacks ->", target.name, "for", dmg)

	# Show enemy attack sprite based on target
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	var enemy_idle_sprite = get_node_or_null("Sprite2D")  # Default enemy sprite
	
	print("🔧 e-block1 exists:", e_block1 != null)
	print("🔧 e-block2 exists:", e_block2 != null)
	print("🔧 enemy idle sprite exists:", enemy_idle_sprite != null)
	
	# Hide default enemy sprite during attack
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = false
	
	if target.name == "Player1" and e_block1:
		e_block1.visible = true
		print("🎬 Showing enemy attack animation for Player1")
	elif target.name == "Player2" and e_block2:
		e_block2.visible = true
		print("🎬 Showing enemy attack animation for Player2")
	else:
		print("❌ No attack sprite found for target:", target.name)

	# Play enemy attack sound
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	if sfx_player:
		sfx_player.stream = preload("res://assets/sfx/miss.wav")
		sfx_player.play()

	if target and target.has_method("take_damage"):
		print("🎯 About to start parry QTE...")
		print("🔧 QTEManager AutoLoad exists:", QTEManager != null)
		
		if QTEManager:
			print("🔧 Calling parry QTE...")
			var qte_result: String = await QTEManager.start_qte("parry", 700, "Press X to parry!", target)
			print("🔧 Parry QTE result:", qte_result)
			
			if qte_result != "fail":
				print("[QTE] Player parried the enemy attack!")
				target.take_damage(0) # no damage if parried
			else:
				print("[QTE] Player failed to parry!")
				target.take_damage(dmg)
		else:
			push_warning("[QTE] QTEManager AutoLoad not found — applying normal damage")
			target.take_damage(dmg)
	
	# Hide enemy attack sprites after QTE resolves
	if e_block1:
		e_block1.visible = false
	if e_block2:
		e_block2.visible = false
	
	# Show default enemy sprite again
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = true
	
	print("🎬 Enemy attack animation finished")

func take_damage(amount: int) -> void:
	if is_defeated:
		return

	hp = max(hp - amount, 0)
	print(name, "takes", amount, "damage. HP:", hp)

	# Update enemy HP bar
	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		if bar.max_value != hp_max:
			bar.min_value = 0
			bar.max_value = hp_max
		bar.value = hp
	else:
		push_warning("Enemy HP bar not found at /root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	
	# Update enemy HP label
	var label: Label = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	if label:
		label.text = "BOSS HP: " + str(hp) + "/" + str(hp_max)
	else:
		push_warning("Enemy HP label not found at /root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	
	# Update health bar above enemy head
	var head_bar: ProgressBar = get_node_or_null("HealthBar")
	if head_bar:
		if head_bar.max_value != hp_max:
			head_bar.min_value = 0
			head_bar.max_value = hp_max
		head_bar.value = hp
	else:
		push_warning("Enemy head HealthBar not found")

	# Show damage popup
	CombatUI.show_damage_popup(self, amount)
	
	# Show flinch animation when taking damage
	if amount > 0:
		show_flinch_animation()

	if hp == 0:
		is_defeated = true
		print(name, "has been defeated!")

# Reset method for combat reset
func reset_for_new_combat():
	hp = hp_max
	is_defeated = false
	
	# Update HP displays to full health
	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		bar.min_value = 0
		bar.max_value = hp_max
		bar.value = hp
	
	var label: Label = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	if label:
		label.text = "BOSS HP: " + str(hp) + "/" + str(hp_max)
	
	# Reset head health bar
	var head_bar: ProgressBar = get_node_or_null("HealthBar")
	if head_bar:
		head_bar.min_value = 0
		head_bar.max_value = hp_max
		head_bar.value = hp
	
	# Make sure idle sprite is visible
	var enemy_idle_sprite = get_node_or_null("Sprite2D")
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = true
		
	# Hide attack sprites
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	if e_block1:
		e_block1.visible = false
	if e_block2:
		e_block2.visible = false
		
	print("RESET→ Enemy reset to initial state")

# Flinch animation when taking damage
func show_flinch_animation() -> void:
	print("FLINCH→ Enemy flinch animation started")
	
	# Get sprite references
	var main_sprite = get_node_or_null("Sprite2D")
	var flinch_sprite = get_node_or_null("flinch")
	var flinch2_sprite = get_node_or_null("flinch2")
	
	if not main_sprite:
		print("FLINCH→ Warning: Main sprite not found")
		return
	
	if not flinch_sprite or not flinch2_sprite:
		print("FLINCH→ Warning: Flinch sprites not found")
		return
	
	# Save original visibility states
	var main_was_visible = main_sprite.visible
	
	# Start flinch sequence: normal → flinch → flinch2 → normal
	# Phase 1: Show flinch sprite
	main_sprite.visible = false
	flinch_sprite.visible = true
	flinch2_sprite.visible = false
	
	await get_tree().create_timer(0.1).timeout  # First flinch frame
	
	# Phase 2: Show flinch2 sprite  
	flinch_sprite.visible = false
	flinch2_sprite.visible = true
	
	await get_tree().create_timer(0.1).timeout  # Second flinch frame
	
	# Phase 3: Return to normal
	flinch2_sprite.visible = false
	main_sprite.visible = main_was_visible
	
	await get_tree().create_timer(0.1).timeout  # Brief hold on normal
	
	print("FLINCH→ Enemy flinch animation complete")
