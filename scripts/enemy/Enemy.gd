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
					sfx_player.stream = preload("res://assets/sfx/phaseslam.wav")
					print("🎵 Playing Phase Slam sound effect")
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

	# Show damage popup
	CombatUI.show_damage_popup(self, amount)

	if hp == 0:
		is_defeated = true
		print(name, "has been defeated!")

# Reset method for combat reset
func reset_for_new_combat():
	hp = hp_max
	is_defeated = false
	
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
