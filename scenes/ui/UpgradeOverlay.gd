extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var iron_will_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/IronWillButton
@onready var berserker_might_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/BerserkerMightButton
@onready var guardian_blessing_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/GuardianBlessingButton
@onready var battle_veteran_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/BattleVeteranButton
@onready var legendary_resilience_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/LegendaryResilienceButton
@onready var master_combatant_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/MasterCombatantButton
@onready var unbreakable_will_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/UnbreakableWillButton
@onready var dual_wielding_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/DualWieldingButton
@onready var vampire_fang_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/VampireFangButton
@onready var finishing_blow_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/FinishingBlowButton
@onready var first_strike_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/FirstStrikeButton
@onready var last_stand_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/LastStandButton
@onready var treasure_hunter_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/TreasureHunterButton
@onready var battle_economist_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/BattleEconomistButton
@onready var bloodlust_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/BloodlustButton
@onready var weapon_master_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/WeaponMasterButton
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons
	if iron_will_button and not iron_will_button.pressed.is_connected(_on_iron_will_pressed):
		iron_will_button.pressed.connect(_on_iron_will_pressed)
	if berserker_might_button and not berserker_might_button.pressed.is_connected(_on_berserker_might_pressed):
		berserker_might_button.pressed.connect(_on_berserker_might_pressed)
	if guardian_blessing_button and not guardian_blessing_button.pressed.is_connected(_on_guardian_blessing_pressed):
		guardian_blessing_button.pressed.connect(_on_guardian_blessing_pressed)
	if battle_veteran_button and not battle_veteran_button.pressed.is_connected(_on_battle_veteran_pressed):
		battle_veteran_button.pressed.connect(_on_battle_veteran_pressed)
	if legendary_resilience_button and not legendary_resilience_button.pressed.is_connected(_on_legendary_resilience_pressed):
		legendary_resilience_button.pressed.connect(_on_legendary_resilience_pressed)
	if master_combatant_button and not master_combatant_button.pressed.is_connected(_on_master_combatant_pressed):
		master_combatant_button.pressed.connect(_on_master_combatant_pressed)
	if unbreakable_will_button and not unbreakable_will_button.pressed.is_connected(_on_unbreakable_will_pressed):
		unbreakable_will_button.pressed.connect(_on_unbreakable_will_pressed)
	if dual_wielding_button and not dual_wielding_button.pressed.is_connected(_on_dual_wielding_pressed):
		dual_wielding_button.pressed.connect(_on_dual_wielding_pressed)
	if vampire_fang_button and not vampire_fang_button.pressed.is_connected(_on_vampire_fang_pressed):
		vampire_fang_button.pressed.connect(_on_vampire_fang_pressed)
	if finishing_blow_button and not finishing_blow_button.pressed.is_connected(_on_finishing_blow_pressed):
		finishing_blow_button.pressed.connect(_on_finishing_blow_pressed)
	if first_strike_button and not first_strike_button.pressed.is_connected(_on_first_strike_pressed):
		first_strike_button.pressed.connect(_on_first_strike_pressed)
	if last_stand_button and not last_stand_button.pressed.is_connected(_on_last_stand_pressed):
		last_stand_button.pressed.connect(_on_last_stand_pressed)
	if treasure_hunter_button and not treasure_hunter_button.pressed.is_connected(_on_treasure_hunter_pressed):
		treasure_hunter_button.pressed.connect(_on_treasure_hunter_pressed)
	if battle_economist_button and not battle_economist_button.pressed.is_connected(_on_battle_economist_pressed):
		battle_economist_button.pressed.connect(_on_battle_economist_pressed)
	if bloodlust_button and not bloodlust_button.pressed.is_connected(_on_bloodlust_pressed):
		bloodlust_button.pressed.connect(_on_bloodlust_pressed)
	if weapon_master_button and not weapon_master_button.pressed.is_connected(_on_weapon_master_pressed):
		weapon_master_button.pressed.connect(_on_weapon_master_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_upgrade():
	print("UPGRADE→ Showing upgrade overlay")
	
	# Update display with current data
	_update_display()
	
	# Make visible and fade in
	visible = true
	if iron_will_button:
		iron_will_button.grab_focus()  # Focus on first upgrade by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_upgrade():
	print("UPGRADE→ Hiding upgrade overlay")
	
	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _update_display():
	# Update coins
	coins_label.text = "Coins: " + str(ProgressManager.player_coins)
	
	# Show upgrade status and descriptions
	iron_will_button.text = "Iron Will (1 coin) - Permanent +2 resolve" + _get_upgrade_status("iron_will")
	berserker_might_button.text = "Berserker's Might (3 coins) - Permanent +25% damage, -10% defense" + _get_upgrade_status("berserker_might")
	guardian_blessing_button.text = "Guardian's Blessing (4 coins) - Permanent +50 max HP" + _get_upgrade_status("guardian_blessing")
	battle_veteran_button.text = "Battle Veteran (4 coins) - Permanent +20% damage, +10% defense" + _get_upgrade_status("battle_veteran")
	legendary_resilience_button.text = "Legendary Resilience (5 coins) - Permanent +100 max HP" + _get_upgrade_status("legendary_resilience")
	master_combatant_button.text = "Master Combatant (6 coins) - Permanent +50% damage to all attacks" + _get_upgrade_status("master_combatant")
	unbreakable_will_button.text = "Unbreakable Will (5 coins) - Start each battle with maximum resolve" + _get_upgrade_status("unbreakable_will")
	dual_wielding_button.text = "Dual Wielding (4 coins) - Both players gain +15% damage" + _get_upgrade_status("dual_wielding")
	vampire_fang_button.text = "Vampire Fang (6 coins) - Permanent lifesteal on all attacks" + _get_upgrade_status("vampire_fang")
	finishing_blow_button.text = "Finishing Blow (4 coins) - Deal +200% damage to enemies below 25% HP" + _get_upgrade_status("finishing_blow")
	first_strike_button.text = "First Strike (3 coins) - Deal +100% damage on your first attack each battle" + _get_upgrade_status("first_strike")
	last_stand_button.text = "Last Stand (4 coins) - Take 50% less damage when below 30% HP" + _get_upgrade_status("last_stand")
	treasure_hunter_button.text = "Treasure Hunter (3 coins) - Gain +1 coin after each battle" + _get_upgrade_status("treasure_hunter")
	battle_economist_button.text = "Battle Economist (4 coins) - All shop items cost 1 less coin (minimum 0)" + _get_upgrade_status("battle_economist")
	bloodlust_button.text = "Bloodlust (4 coins) - Lifesteal 25% of damage dealt when attacking for 50+ damage" + _get_upgrade_status("bloodlust")
	weapon_master_button.text = "Weapon Master (5 coins) - 20% chance to deal double damage" + _get_upgrade_status("weapon_master")

	# Disable buttons if not enough coins or already purchased
	iron_will_button.disabled = ProgressManager.player_coins < 1 or ProgressManager.is_upgrade_purchased("iron_will")
	berserker_might_button.disabled = ProgressManager.player_coins < 3 or ProgressManager.is_upgrade_purchased("berserker_might")
	guardian_blessing_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("guardian_blessing")
	battle_veteran_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("battle_veteran")
	legendary_resilience_button.disabled = ProgressManager.player_coins < 5 or ProgressManager.is_upgrade_purchased("legendary_resilience")
	master_combatant_button.disabled = ProgressManager.player_coins < 6 or ProgressManager.is_upgrade_purchased("master_combatant")
	unbreakable_will_button.disabled = ProgressManager.player_coins < 5 or ProgressManager.is_upgrade_purchased("unbreakable_will")
	dual_wielding_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("dual_wielding")
	vampire_fang_button.disabled = ProgressManager.player_coins < 6 or ProgressManager.is_upgrade_purchased("vampire_fang")
	finishing_blow_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("finishing_blow")
	first_strike_button.disabled = ProgressManager.player_coins < 3 or ProgressManager.is_upgrade_purchased("first_strike")
	last_stand_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("last_stand")
	treasure_hunter_button.disabled = ProgressManager.player_coins < 3 or ProgressManager.is_upgrade_purchased("treasure_hunter")
	battle_economist_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("battle_economist")
	bloodlust_button.disabled = ProgressManager.player_coins < 4 or ProgressManager.is_upgrade_purchased("bloodlust")
	weapon_master_button.disabled = ProgressManager.player_coins < 5 or ProgressManager.is_upgrade_purchased("weapon_master")

func _get_upgrade_status(upgrade_name: String) -> String:
	if ProgressManager.is_upgrade_purchased(upgrade_name):
		return " [OWNED]"
	return ""

func _buy_upgrade(upgrade_name: String):
	if ProgressManager.buy_upgrade(upgrade_name):
		print("UPGRADE→ Successfully bought ", upgrade_name)
		_update_display()  # Refresh display after purchase
	else:
		print("UPGRADE→ Failed to buy ", upgrade_name)

func _on_iron_will_pressed():
	_buy_upgrade("iron_will")

func _on_berserker_might_pressed():
	_buy_upgrade("berserker_might")

func _on_guardian_blessing_pressed():
	_buy_upgrade("guardian_blessing")

func _on_battle_veteran_pressed():
	_buy_upgrade("battle_veteran")

func _on_legendary_resilience_pressed():
	_buy_upgrade("legendary_resilience")

func _on_master_combatant_pressed():
	_buy_upgrade("master_combatant")

func _on_unbreakable_will_pressed():
	_buy_upgrade("unbreakable_will")

func _on_dual_wielding_pressed():
	_buy_upgrade("dual_wielding")

func _on_vampire_fang_pressed():
	_buy_upgrade("vampire_fang")

func _on_finishing_blow_pressed():
	_buy_upgrade("finishing_blow")

func _on_first_strike_pressed():
	_buy_upgrade("first_strike")

func _on_last_stand_pressed():
	_buy_upgrade("last_stand")

func _on_treasure_hunter_pressed():
	_buy_upgrade("treasure_hunter")

func _on_battle_economist_pressed():
	_buy_upgrade("battle_economist")

func _on_bloodlust_pressed():
	_buy_upgrade("bloodlust")

func _on_weapon_master_pressed():
	_buy_upgrade("weapon_master")

func _on_close_pressed():
	print("UPGRADE→ Leaving upgrade shop")
	hide_upgrade()
	
	# Advance progression and start next battle
	_start_next_battle()

func _start_next_battle():
	print("UPGRADE→ Starting next battle")

	# Get TurnManager and BackgroundManager for next battle
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	var background_manager = get_node_or_null("/root/BattleScene/BackgroundManager")
	var background_sprite = get_node_or_null("/root/BattleScene/Background")

	# Change background before starting new battle
	if background_manager and background_sprite:
		background_manager.change_battle_background(background_sprite)
		print("UPGRADE→ Background randomized for next battle")

	if turn_manager:
		# Reset combat for next battle
		turn_manager.reset_combat()
		# Start new turn cycle
		turn_manager.change_state(turn_manager.State.BEGIN_TURN)
		print("UPGRADE→ Next battle started successfully")
	else:
		print("ERROR→ Could not find TurnManager to start next battle")