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

# Assignment dialog (created dynamically)
var assignment_dialog: Control = null
var pending_upgrade_name: String = ""
var pending_upgrade_data: Dictionary = {}

# TabContainer will handle tab selection automatically

# Shop data pools
var items_pool := [
	{"name": "Health Potion", "cost": 1, "description": "Restores 50 HP instantly"},
	{"name": "Resolve Potion", "cost": 1, "description": "Restores 2 Resolve points"},
	{"name": "Rage Potion", "cost": 2, "description": "Gain rage status: +100% damage, +25% incoming damage for 3 turns"},
	{"name": "Speed Boost", "cost": 2, "description": "Gain haste status: act twice per turn for 2 turns"},
	{"name": "Pain Killer", "cost": 2, "description": "Immune to damage for 1 hit"},
	{"name": "Bandages", "cost": 1, "description": "Heal 15 HP at start of each turn for 3 turns"},
	{"name": "Phoenix Feather", "cost": 2, "description": "Revive with 50% HP if you die this battle"}
]

var upgrades_pool := [
	{"name": "Iron Skin", "cost": 3, "description": "Permanent +10 damage reduction"},
	{"name": "Vampire Fang", "cost": 6, "description": "Permanent lifesteal on all attacks"},
	{"name": "Guardian Angel", "cost": 6, "description": "One-time revive protection"},
	{"name": "Lucky Coin", "cost": 1, "description": "Gain +2 coins if you win battles"},
	# TEMP: Testing upgrades - remove after implementation
	{"name": "Strong Body", "cost": 2, "description": "Permanent +25 max HP"},
	{"name": "Combat Training", "cost": 2, "description": "Permanent +10% damage to all attacks"},
	{"name": "Thick Skin", "cost": 2, "description": "Permanent -10% damage taken"}
]

var abilities_p1_pool := ["2x_cut", "moonfall_slash", "spirit_wave", "whirlwind", "ghost_attack"]
var abilities_p2_pool := ["big_shot", "scatter_shot", "grenade", "bullet_rain"]
var abilities_shared_pool := ["poison", "burn_strike", "shield_boost", "mark_target", "freezing_shot", "armor_piercing", "bleeding_shot", "berserker_rage", "healing_touch", "curse_strike", "time_shift", "energy_barrier"]

# Current shop offerings (randomized each visit)
var current_items := []
var current_upgrades := []
var current_abilities := []

# Track purchases for this shop visit (reset each visit)
var purchased_items := []

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

	# Reset purchases for new shop visit
	purchased_items.clear()

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

		# Check if item already purchased this visit
		if item.name in purchased_items:
			button.text = "%s - SOLD" % item.name
			button.disabled = true
		else:
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

		# Check if upgrade already purchased this campaign
		var display_name_mapping = {
			"Berserker's Might": "berserker_might",
			"Guardian's Blessing": "guardian_blessing",
			"Battle Veteran": "battle_veteran",
			"Legendary Resilience": "legendary_resilience",
			"Master Combatant": "master_combatant",
			"Unbreakable Will": "unbreakable_will",
			"Dual Wielding": "dual_wielding",
			"Vampire Fang": "vampire_fang",
			"Finishing Blow": "finishing_blow",
			"First Strike": "first_strike",
			"Last Stand": "last_stand",
			"Treasure Hunter": "treasure_hunter",
			"Battle Economist": "battle_economist",
			"Bloodlust": "bloodlust",
			"Weapon Master": "weapon_master"
		}
		var upgrade_key = display_name_mapping.get(upgrade.name, upgrade.name.replace(" ", "_").replace("'", "").to_lower())
		if ProgressManager.is_upgrade_purchased(upgrade_key):
			button.text = "%s - PURCHASED" % upgrade.name
			button.disabled = true
		else:
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
	print("SHOP→ Attempting to buy: ", item_name)

	# Map shop display names to inventory keys
	var item_mapping = {
		"Health Potion": "hp_potion",
		"Resolve Potion": "resolve_potion",
		"Rage Potion": "rage_potion",
		"Speed Boost": "speed_boost",
		"Pain Killer": "pain_killer",
		"Bandages": "bandages",
		"Phoenix Feather": "phoenix_feather"
	}

	# Find the item data to get cost
	var item_data = null
	for item in current_items:
		if item.name == item_name:
			item_data = item
			break

	if not item_data:
		print("ERROR→ Item not found: ", item_name)
		return

	var cost = item_data.cost
	var inventory_key = item_mapping.get(item_name)

	if not inventory_key:
		print("ERROR→ No inventory mapping for: ", item_name)
		return

	# Check if item already purchased this visit
	if item_name in purchased_items:
		print("SHOP→ Already purchased ", item_name, " this visit!")
		return

	# Check if player has enough coins
	if ProgressManager.player_coins < cost:
		print("SHOP→ Not enough coins! Need ", cost, ", have ", ProgressManager.player_coins)
		return

	# Purchase successful - deduct coins and add item
	ProgressManager.spend_coins(cost)
	ProgressManager.party_inventory[inventory_key] += 1

	# Track this purchase for current shop visit
	purchased_items.append(item_name)

	print("SHOP→ Successfully bought ", item_name, " for ", cost, " coins")
	print("SHOP→ ", inventory_key, " count now: ", ProgressManager.party_inventory[inventory_key])

	# Update the display to show new coin amount (preserve current tab)
	_update_display_after_purchase()

func _buy_upgrade(upgrade_name: String):
	print("SHOP→ Attempting to buy upgrade: ", upgrade_name)

	# Find the upgrade data to get cost
	var upgrade_data = null
	for upgrade in current_upgrades:
		if upgrade.name == upgrade_name:
			upgrade_data = upgrade
			break

	if not upgrade_data:
		print("ERROR→ Upgrade not found: ", upgrade_name)
		return

	# Convert display names to internal keys
	var upgrade_name_mapping = {
		"Berserker's Might": "berserker_might",
		"Guardian's Blessing": "guardian_blessing",
		"Battle Veteran": "battle_veteran",
		"Legendary Resilience": "legendary_resilience",
		"Master Combatant": "master_combatant",
		"Unbreakable Will": "unbreakable_will",
		"Dual Wielding": "dual_wielding",
		"Vampire Fang": "vampire_fang",
		"Finishing Blow": "finishing_blow",
		"First Strike": "first_strike",
		"Last Stand": "last_stand",
		"Treasure Hunter": "treasure_hunter",
		"Battle Economist": "battle_economist",
		"Bloodlust": "bloodlust",
		"Weapon Master": "weapon_master"
	}
	var upgrade_key = upgrade_name_mapping.get(upgrade_name, upgrade_name.replace(" ", "_").replace("'", "").to_lower())

	# Check if already purchased (once per campaign)
	if ProgressManager.is_upgrade_purchased(upgrade_key):
		print("SHOP→ Already purchased ", upgrade_name, " this campaign!")
		return

	# Check if player has enough coins
	if ProgressManager.player_coins < upgrade_data.cost:
		print("SHOP→ Not enough coins! Need ", upgrade_data.cost, ", have ", ProgressManager.player_coins)
		return

	# Store pending purchase and show assignment dialog
	pending_upgrade_name = upgrade_key
	pending_upgrade_data = upgrade_data

	# Special cases: Party-wide upgrades apply to both players automatically
	if upgrade_key in ["dual_wielding", "treasure_hunter", "battle_economist"]:
		_assign_party_upgrade_to_both_players()
	else:
		_show_assignment_dialog()

func _assign_party_upgrade_to_both_players():
	print("SHOP→ ", pending_upgrade_data.name, ": assigning to both players automatically (party-wide upgrade)")

	# Complete the purchase
	ProgressManager.spend_coins(pending_upgrade_data.cost)

	# Assign to both players
	ProgressManager.assign_upgrade_to_player(pending_upgrade_name, "Player1")
	ProgressManager.assign_upgrade_to_player(pending_upgrade_name, "Player2")

	print("SHOP→ Successfully bought ", pending_upgrade_data.name, " for both players (", pending_upgrade_data.cost, " coins)")

	# Update combat UI to show new upgrade for both players
	var combat_ui = get_node_or_null("/root/BattleScene/CombatUI")
	if combat_ui and combat_ui.has_method("update_player_upgrades_display"):
		combat_ui.update_player_upgrades_display("Player1")
		combat_ui.update_player_upgrades_display("Player2")

	# Update shop display
	_update_display_after_purchase()

# Legacy function name for compatibility
func _assign_dual_wielding_to_both_players():
	_assign_party_upgrade_to_both_players()

func _buy_ability(ability_name: String):
	print("SHOP→ [PLACEHOLDER] Buying ability: ", ability_name)
	# TODO: Implement actual ability unlock logic

# Show modal assignment dialog
func _show_assignment_dialog():
	# Create modal overlay
	assignment_dialog = ColorRect.new()
	assignment_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assignment_dialog.color = Color(0, 0, 0, 0.7)  # Semi-transparent background

	# Create dialog panel
	var dialog_panel = Panel.new()
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dialog_panel.size = Vector2(400, 300)
	assignment_dialog.add_child(dialog_panel)

	# Create content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	dialog_panel.add_child(vbox)

	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(content_vbox)

	# Title
	var title = Label.new()
	title.text = "ASSIGN UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content_vbox.add_child(title)

	# Upgrade info
	var upgrade_info = Label.new()
	upgrade_info.text = pending_upgrade_data.name + "\nCost: " + str(pending_upgrade_data.cost) + " coins\n" + pending_upgrade_data.description
	upgrade_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(upgrade_info)

	# Assignment question
	var question = Label.new()
	question.text = "Assign to which player?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(question)

	# Player buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	content_vbox.add_child(button_container)

	var player1_button = Button.new()
	player1_button.text = "Player1"
	player1_button.pressed.connect(_assign_to_player.bind("Player1"))
	button_container.add_child(player1_button)

	var player2_button = Button.new()
	player2_button.text = "Player2"
	player2_button.pressed.connect(_assign_to_player.bind("Player2"))
	button_container.add_child(player2_button)

	# Cancel button
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_cancel_assignment)
	content_vbox.add_child(cancel_button)

	# Add to scene
	add_child(assignment_dialog)
	print("SHOP→ Showing assignment dialog for: ", pending_upgrade_data.name)

# Assign upgrade to selected player
func _assign_to_player(player_name: String):
	print("SHOP→ Assigning ", pending_upgrade_name, " to ", player_name)

	# Complete the purchase
	ProgressManager.spend_coins(pending_upgrade_data.cost)
	ProgressManager.assign_upgrade_to_player(pending_upgrade_name, player_name)

	print("SHOP→ Successfully bought ", pending_upgrade_data.name, " for ", player_name, " (", pending_upgrade_data.cost, " coins)")

	# Update combat UI to show new upgrade
	var combat_ui = get_node_or_null("/root/BattleScene/CombatUI")
	if combat_ui and combat_ui.has_method("update_player_upgrades_display"):
		combat_ui.update_player_upgrades_display(player_name)

	# Close dialog and update shop display
	_close_assignment_dialog()
	_update_display_after_purchase()

# Cancel assignment dialog
func _cancel_assignment():
	print("SHOP→ Assignment cancelled")
	_close_assignment_dialog()

# Close and cleanup assignment dialog
func _close_assignment_dialog():
	if assignment_dialog:
		assignment_dialog.queue_free()
		assignment_dialog = null
	pending_upgrade_name = ""
	pending_upgrade_data = {}

func _on_close_pressed():
	print("SHOP→ Leaving shop")
	hide_shop()
	
	# Advance progression and start next battle
	_start_next_battle()

func _update_display_after_purchase():
	# Save current tab before updating
	var current_tab_index = -1
	if tab_container:
		current_tab_index = tab_container.current_tab

	# Update the full display (includes refreshing items with SOLD status)
	_update_display()

	# Restore the previously selected tab
	if tab_container and current_tab_index >= 0:
		tab_container.current_tab = current_tab_index
		print("SHOP→ Restored tab selection to index: ", current_tab_index)

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
