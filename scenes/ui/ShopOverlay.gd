extends Control

# UI References
@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

# Tab system
@onready var tab_container := $Panel/VBoxContainer/TabContainer
@onready var items_tab := $Panel/VBoxContainer/TabContainer/Items
@onready var upgrades_tab := $Panel/VBoxContainer/TabContainer/Upgrades
@onready var abilities_tab := $Panel/VBoxContainer/TabContainer/Abilities

# TabContainer will handle tab selection automatically

# Shop data pools
var items_pool := [
	{"name": "Health Potion", "cost": 1, "description": "Restores 50 HP instantly"},
	{"name": "Resolve Potion", "cost": 1, "description": "Restores 2 Resolve points"},
	{"name": "Antidote", "cost": 1, "description": "Removes poison/bleeding effects"},
	{"name": "Pain Killer", "cost": 2, "description": "Immune to damage for 1 hit"},
	{"name": "Bandages", "cost": 1, "description": "Heal 15 HP at start of each turn for 3 turns"},
	{"name": "Phoenix Feather", "cost": 2, "description": "Revive with 50% HP if you die this battle"}
]

var upgrades_pool := [
	{"name": "Iron Skin", "cost": 3, "description": "Permanent +10 damage reduction"},
	{"name": "Vampire Fang", "cost": 6, "description": "Permanent lifesteal on all attacks"},
	{"name": "Guardian Angel", "cost": 6, "description": "One-time revive protection"},
	{"name": "Lucky Coin", "cost": 1, "description": "Gain +2 coins if you win battles"}
]

var abilities_p1_pool := ["2x_cut", "moonfall_slash", "spirit_wave", "whirlwind", "ghost_attack"]
var abilities_p2_pool := ["big_shot", "scatter_shot", "grenade", "bullet_rain"]
var abilities_shared_pool := ["poison", "burn_strike", "shield_boost", "mark_target", "freezing_shot", "armor_piercing", "bleeding_shot", "berserker_rage", "healing_touch", "curse_strike", "time_shift", "energy_barrier"]

# Current shop offerings (randomized each visit)
var current_items := []
var current_upgrades := []
var current_abilities := []

# RNG for randomization
@onready var rng := RandomNumberGenerator.new()

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0

	# Initialize RNG
	rng.randomize()

	# Connect close button
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_shop():
	print("SHOP→ Showing shop overlay")

	# Randomize shop offerings for this visit
	_randomize_shop_offerings()

	# Update display with current data
	_update_display()

	# Make visible and fade in
	visible = true

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_shop():
	print("SHOP→ Hiding shop overlay")
	
	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _randomize_shop_offerings():
	print("SHOP→ Randomizing shop offerings")

	# Randomize Items (2-3 items)
	current_items.clear()
	var item_count = rng.randi_range(2, 3)
	var available_items = items_pool.duplicate()
	for i in range(item_count):
		if available_items.size() > 0:
			var random_index = rng.randi() % available_items.size()
			current_items.append(available_items[random_index])
			available_items.remove_at(random_index)

	# Randomize Upgrades (2-3 upgrades)
	current_upgrades.clear()
	var upgrade_count = rng.randi_range(2, 3)
	var available_upgrades = upgrades_pool.duplicate()
	for i in range(upgrade_count):
		if available_upgrades.size() > 0:
			var random_index = rng.randi() % available_upgrades.size()
			current_upgrades.append(available_upgrades[random_index])
			available_upgrades.remove_at(random_index)

	# Randomize Abilities (4 total: 2 shared, 1 P1, 1 P2)
	current_abilities.clear()

	# 2 shared status abilities
	var shared_pool = abilities_shared_pool.duplicate()
	for i in range(2):
		if shared_pool.size() > 0:
			var random_index = rng.randi() % shared_pool.size()
			current_abilities.append(shared_pool[random_index])
			shared_pool.remove_at(random_index)

	# 1 Player1 ability
	if abilities_p1_pool.size() > 0:
		var p1_index = rng.randi() % abilities_p1_pool.size()
		current_abilities.append(abilities_p1_pool[p1_index])

	# 1 Player2 ability
	if abilities_p2_pool.size() > 0:
		var p2_index = rng.randi() % abilities_p2_pool.size()
		current_abilities.append(abilities_p2_pool[p2_index])

	print("SHOP→ Items: ", current_items.size())
	print("SHOP→ Upgrades: ", current_upgrades.size())
	print("SHOP→ Abilities: ", current_abilities.size())

func _update_display():
	# Update coins
	coins_label.text = "Coins: " + str(ProgressManager.player_coins)

	# Get current battle number to determine available tabs
	# Since shop opens AFTER completing battle, show content for completed battle number
	var completed_battle = ProgressManager.get_current_battle_number()

	# Clear existing items from all tabs
	_clear_all_tabs()

	# Control tab visibility based on battle progression
	_control_tab_access(completed_battle)

	# Populate tabs based on completed battles
	_populate_items_tab()  # Always available

	if completed_battle >= 2:  # After battle 2, unlock upgrades
		_populate_upgrades_tab()

	if completed_battle >= 3:  # After battle 3, unlock abilities
		_populate_abilities_tab()

	title_label.text = "Shop"
	print("SHOP→ Tabs populated after completing battle ", completed_battle)

func _clear_all_tabs():
	# Clear Items tab
	var items_container = $Panel/VBoxContainer/TabContainer/Items/ItemsContainer
	if items_container:
		for child in items_container.get_children():
			child.queue_free()

	# Clear Upgrades tab
	var upgrades_container = $Panel/VBoxContainer/TabContainer/Upgrades/UpgradesContainer
	if upgrades_container:
		for child in upgrades_container.get_children():
			child.queue_free()

	# Clear Abilities tab
	var abilities_container = $Panel/VBoxContainer/TabContainer/Abilities/AbilitiesContainer
	if abilities_container:
		for child in abilities_container.get_children():
			child.queue_free()

func _populate_items_tab():
	var items_container = $Panel/VBoxContainer/TabContainer/Items/ItemsContainer
	if not items_container:
		print("ERROR→ Items container not found")
		return

	for item in current_items:
		var button = Button.new()
		button.text = "%s (%d coins) - %s" % [item.name, item.cost, item.description]
		button.pressed.connect(_buy_item.bind(item.name))
		items_container.add_child(button)

func _populate_upgrades_tab():
	var upgrades_container = $Panel/VBoxContainer/TabContainer/Upgrades/UpgradesContainer
	if not upgrades_container:
		print("ERROR→ Upgrades container not found")
		return

	for upgrade in current_upgrades:
		var button = Button.new()
		button.text = "%s (%d coins) - %s" % [upgrade.name, upgrade.cost, upgrade.description]
		button.pressed.connect(_buy_upgrade.bind(upgrade.name))
		upgrades_container.add_child(button)

func _populate_abilities_tab():
	var abilities_container = $Panel/VBoxContainer/TabContainer/Abilities/AbilitiesContainer
	if not abilities_container:
		print("ERROR→ Abilities container not found")
		return

	for ability in current_abilities:
		var button = Button.new()
		var ability_name = ability.replace("_", " ").capitalize()
		button.text = "%s (3 coins) - Unlock new combat ability" % ability_name
		button.pressed.connect(_buy_ability.bind(ability))
		abilities_container.add_child(button)

func _control_tab_access(completed_battle: int):
	# Hide/show tabs based on completed battles
	if upgrades_tab:
		upgrades_tab.visible = completed_battle >= 2  # Unlock after battle 2

	if abilities_tab:
		abilities_tab.visible = completed_battle >= 3  # Unlock after battle 3

	print("SHOP→ Tab access after battle ", completed_battle, ": Items=true, Upgrades=", completed_battle >= 2, ", Abilities=", completed_battle >= 3)

func _buy_item(item_name: String):
	print("SHOP→ [PLACEHOLDER] Buying: ", item_name)
	# TODO: Implement actual purchase logic

func _buy_upgrade(upgrade_name: String):
	print("SHOP→ [PLACEHOLDER] Buying upgrade: ", upgrade_name)
	# TODO: Implement actual upgrade logic

func _buy_ability(ability_name: String):
	print("SHOP→ [PLACEHOLDER] Buying ability: ", ability_name)
	# TODO: Implement actual ability unlock logic

func _on_close_pressed():
	print("SHOP→ Leaving shop")
	hide_shop()
	
	# Advance progression and start next battle
	_start_next_battle()

func _start_next_battle():
	print("SHOP→ Starting next battle")

	# Advance progression to next battle
	ProgressManager.advance_position()
	print("SHOP→ Advanced to battle ", ProgressManager.get_current_battle_number())

	# Get TurnManager and BackgroundManager for next battle
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	var background_manager = get_node_or_null("/root/BattleScene/BackgroundManager")
	var background_sprite = get_node_or_null("/root/BattleScene/Background")

	# Change background before starting new battle
	if background_manager and background_sprite:
		background_manager.change_battle_background(background_sprite)
		print("SHOP→ Background randomized for next battle")

	if turn_manager:
		# Reset combat for next battle
		turn_manager.reset_combat()
		# Start new turn cycle
		turn_manager.change_state(turn_manager.State.BEGIN_TURN)
		print("SHOP→ Next battle started successfully")
	else:
		print("ERROR→ Could not find TurnManager to start next battle")
