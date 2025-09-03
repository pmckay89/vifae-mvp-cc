extends Node2D

# Enemy stats only - no turn management
var base_hp_max: int = 300  # Base HP for Battle 1
var hp_max: int = base_hp_max  # Will be scaled based on progression
var hp: int = hp_max
var is_defeated: bool = false
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
	# Scale HP based on current battle progression
	_scale_for_current_battle()
	
	_update_idle_animation()
	
	# Initialize HP bar color to full health (green)
	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		bar.min_value = 0
		bar.max_value = hp_max
		bar.value = hp
		_update_hp_bar_color(bar)
	
	# Hide head health bar permanently
	var head_bar: ProgressBar = get_node_or_null("HealthBar")
	if head_bar:
		head_bar.visible = false

func _update_idle_animation():
	var animated_sprite = get_node_or_null("Sprite2D") as AnimatedSprite2D
	if animated_sprite:
		var health_percentage = float(hp) / float(hp_max)
		if health_percentage <= 0.5:
			if animated_sprite.animation != "idle2":
				animated_sprite.play("idle2")
				print("🎬 Switched to idle2 animation (HP ≤ 50%)")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
				print("🎬 Using idle animation (HP > 50%)")

# This is called by the new TurnManager system for enemy attack animations
func attack_animation(target: Node, attack_type: String = "", play_sound: bool = true) -> void:
	print("🔥 ENEMY ATTACK ANIMATION - target:", target.name, "attack:", attack_type)
	if is_defeated:
		return

	# Show enemy attack sprite based on target
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	var enemy_idle_sprite = get_node_or_null("Sprite2D")  # Now AnimatedSprite2D with idle animation
	
	print("🔧 e-block1 exists:", e_block1 != null)
	print("🔧 e-block2 exists:", e_block2 != null)
	print("🔧 enemy idle sprite exists:", enemy_idle_sprite != null)
	
	# Special cases - keep enemy in idle position for ranged attacks
	if attack_type == "multishot" or attack_type == "mirror_strike":
		print("🎯 ", attack_type, " attack - keeping enemy in idle position")
		# Keep idle sprite visible, don't show attack sprites
		if enemy_idle_sprite:
			enemy_idle_sprite.visible = true
		return
	
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

# Note: show_block_animation no longer needed - VFXManager now handles enemy hits properly

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

	# Update enemy HP bar with color gradient
	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		if bar.max_value != hp_max:
			bar.min_value = 0
			bar.max_value = hp_max
		bar.value = hp
		_update_hp_bar_color(bar)
	else:
		push_warning("Enemy HP bar not found at /root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	
	# Update enemy HP label
	var label: Label = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	if label:
		label.text = "BOSS HP: " + str(hp) + "/" + str(hp_max)
	else:
		push_warning("Enemy HP label not found at /root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	
	# Hide health bar above enemy head (permanently disabled for now)
	var head_bar: ProgressBar = get_node_or_null("HealthBar")
	if head_bar:
		head_bar.visible = false
		head_bar.value = hp
	else:
		push_warning("Enemy head HealthBar not found")

	# Show damage popup
	CombatUI.show_damage_popup(self, amount)
	
	# Show flinch animation when taking damage
	if amount > 0:
		show_flinch_animation()

	# Check if we need to switch idle animations based on new HP
	_update_idle_animation()

	if hp == 0:
		is_defeated = true
		print(name, "has been defeated!")


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
	
	# Phase 3: Always return to visible main sprite (ensure enemy doesn't disappear)
	flinch2_sprite.visible = false
	main_sprite.visible = true  # Force main sprite to be visible
	
	await get_tree().create_timer(0.1).timeout  # Brief hold on normal
	
	print("FLINCH→ Enemy flinch animation complete")

func _update_hp_bar_color(bar: ProgressBar):
	if not bar:
		return
	
	var hp_percentage = float(hp) / float(hp_max)
	var fill_color: Color
	
	# Create gradient: Green (100%) → Yellow (≈60%) → Red (≈30%)
	if hp_percentage > 0.6:
		# Green to Yellow transition (100% to 60%)
		var transition = (hp_percentage - 0.6) / 0.4  # 0.0 to 1.0
		fill_color = Color.YELLOW.lerp(Color.GREEN, transition)
	elif hp_percentage > 0.3:
		# Yellow to Red transition (60% to 30%)
		var transition = (hp_percentage - 0.3) / 0.3  # 0.0 to 1.0  
		fill_color = Color.RED.lerp(Color.YELLOW, transition)
	else:
		# Pure Red (30% and below)
		fill_color = Color.RED
	
	# Create new StyleBoxFlat with the calculated color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = fill_color
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(1, 0.4, 0.4, 1)  # Keep original border
	
	# Apply the new style
	bar.add_theme_stylebox_override("fill", style_box)
	
	print("HP Bar color updated: ", int(hp_percentage * 100), "% -> ", fill_color)

# Scale enemy stats based on battle progression
func _scale_for_current_battle():
	var hp_multiplier = ProgressManager.get_enemy_hp_multiplier()
	hp_max = int(base_hp_max * hp_multiplier)
	hp = hp_max  # Set current HP to new max
	
	var battle_number = ProgressManager.get_current_battle_number()
	print("ENEMY→ Battle ", battle_number, ": Scaled to ", hp_max, " HP (", int(hp_multiplier * 100), "% of base)")

# Reset enemy for new combat (called by TurnManager)
func reset_for_new_combat():
	is_defeated = false
	_scale_for_current_battle()  # Re-scale for current battle (sets hp = hp_max)
	
	# Update HP displays to match new scaled values
	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		bar.min_value = 0
		bar.max_value = hp_max
		bar.value = hp
		_update_hp_bar_color(bar)
	
	var label: Label = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
	if label:
		label.text = "BOSS HP: " + str(hp) + "/" + str(hp_max)
	
	# Reset head health bar  
	var head_bar: ProgressBar = get_node_or_null("HealthBar")
	if head_bar:
		head_bar.min_value = 0
		head_bar.max_value = hp_max
		head_bar.value = hp
		head_bar.visible = false  # Keep it hidden
	
	# Make sure idle sprite is visible and attack sprites are hidden
	var enemy_idle_sprite = get_node_or_null("Sprite2D")
	if enemy_idle_sprite:
		enemy_idle_sprite.visible = true
	
	var e_block1 = get_node_or_null("e-block")
	var e_block2 = get_node_or_null("e-block2")
	if e_block1:
		e_block1.visible = false
	if e_block2:
		e_block2.visible = false
	
	_update_idle_animation()
	print("ENEMY→ Reset for new combat - HP: ", hp, "/", hp_max)
