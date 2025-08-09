extends Node2D

# Enemy stats only - no turn management
var hp_max: int = 150
var hp: int = hp_max
var is_defeated: bool = false
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()

func attack(target: Node) -> void:
	print("🔥 ENEMY ATTACK STARTED - target:", target.name)
	if is_defeated:
		return

	var dmg := rng.randi_range(6, 12)
	print(name, "attacks ->", target.name, "for", dmg)

	# Play enemy attack sound
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	if sfx_player:
		sfx_player.stream = preload("res://assets/sfx/menu.wav")  # Add this sound file
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
