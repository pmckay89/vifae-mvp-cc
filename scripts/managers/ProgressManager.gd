extends Node

# Slay the Spire style progression manager
# Tracks player's journey through linear A/B fork system

signal node_changed(new_position)
signal coins_changed(new_amount)

enum NodeType {
	BATTLE,
	SHOP,
	UPGRADE
}

# Simple linear progression: Battle → Fork (Shop A | Upgrade B) → Battle → Fork...
var current_position: int = 0
var player_coins: int = 0  # Currency earned from battles

# Shared party inventory (empty for discovery gameplay)
var party_inventory = {
	"hp_potion": 0,        # Hidden until purchased
	"resolve_potion": 0,   # Hidden until purchased
	"bandages": 0,         # Hidden until purchased
	"phoenix_feather": 0,  # Hidden until purchased
	"rage_potion": 0,      # Hidden until purchased
	"speed_boost": 0,      # Hidden until purchased
	"pain_killer": 0       # Hidden until purchased
}

# Temporary battle buffs from shop
var active_buffs = {
	"power_boost": false,     # 2x damage next battle
	"quick_reflexes": false   # Slower QTE windows next battle
}

# Permanent player upgrades (assigned to specific players)
var player_upgrades = {
	"Player1": {
		# Example: "iron_will": true, "combat_training": true
	},
	"Player2": {
		# Example: "thick_skin": true, "strong_body": true
	}
}

# Track purchased upgrades to prevent duplicates (once per campaign)
var purchased_upgrades = []

# Battle flags for tracking per-battle effects (reset each battle)
var battle_flags = {}

# Map structure: array of fork choices (what comes after each battle)
var map_structure = [
	{"battle_name": "Tutorial Boss", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE},
	{"battle_name": "Shadow Beast", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE},
	{"battle_name": "Elite Guardian", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE},
	{"battle_name": "Ancient Warden", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE},
	{"battle_name": "Final Boss", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE}
]

var selected_path: String = ""  # "A" or "B" - tracks player's last choice

func _ready():
	print("PROGRESS→ ProgressManager initialized")
	print("PROGRESS→ Starting coins: ", player_coins)

	# DEBUG: Add test upgrades for demonstration
	# player_upgrades["Player1"]["iron_will"] = true
	# player_upgrades["Player1"]["combat_training"] = true
	# player_upgrades["Player2"]["thick_skin"] = true
	# print("PROGRESS→ DEBUG: Added test upgrades for demonstration")

# Called after battle victory
func complete_battle():
	var coins_earned = get_battle_coin_reward()  # Progressive scaling based on battle

	# Apply Treasure Hunter bonus (+1 coin per battle)
	if has_player_upgrade("Player1", "treasure_hunter") or has_player_upgrade("Player2", "treasure_hunter"):
		coins_earned += 1
		print("PROGRESS→ Treasure Hunter bonus: +1 coin")

	player_coins += coins_earned
	coins_changed.emit(player_coins)  # Emit signal for UI update
	print("PROGRESS→ Battle completed! Earned ", coins_earned, " coins (total: ", player_coins, ")")

	# Check if there are more battles/choices ahead
	if current_position < map_structure.size() - 1:
		print("PROGRESS→ Fork available - player can choose next path")
	else:
		print("PROGRESS→ Map completed!")

# Player chooses A or B path at fork
func choose_path(choice: String):
	if choice != "A" and choice != "B":
		print("ERROR→ Invalid path choice: ", choice)
		return
		
	selected_path = choice
	var node_type = map_structure[current_position]["fork_" + choice.to_lower()]
	
	print("PROGRESS→ Player chose path ", choice, " (", NodeType.keys()[node_type], ")")
	
	# Advance to next position after visiting shop/upgrade
	advance_position()

func advance_position():
	current_position += 1
	node_changed.emit(current_position)
	print("PROGRESS→ Advanced to position ", current_position)

# Shop functions
func spend_coins(amount: int) -> bool:
	if player_coins >= amount:
		player_coins -= amount
		coins_changed.emit(player_coins)  # Emit signal for UI update
		print("PROGRESS→ Spent ", amount, " coins (remaining: ", player_coins, ")")
		return true
	else:
		print("PROGRESS→ Not enough coins! Need ", amount, ", have ", player_coins)
		return false

func add_coins(amount: int):
	player_coins += amount
	coins_changed.emit(player_coins)  # Emit signal for UI update
	print("PROGRESS→ Added ", amount, " coins (total: ", player_coins, ")")

# Getters
func get_current_battle() -> Dictionary:
	if current_position < map_structure.size():
		return map_structure[current_position]
	return {}

func get_available_choices() -> Array:
	var battle = get_current_battle()
	if battle.is_empty():
		return []
	
	return [
		{"path": "A", "type": battle.fork_a, "name": NodeType.keys()[battle.fork_a]},
		{"path": "B", "type": battle.fork_b, "name": NodeType.keys()[battle.fork_b]}
	]

func has_choices_available() -> bool:
	return current_position < map_structure.size() - 1

# Shop functions (consumables and temporary buffs only)
func buy_item(item_name: String) -> bool:
	var cost = 1  # All items cost 1 coin

	# Apply Battle Economist discount (-1 cost, minimum 0)
	if has_player_upgrade("Player1", "battle_economist") or has_player_upgrade("Player2", "battle_economist"):
		cost = max(0, cost - 1)
		if cost == 0:
			print("SHOP→ Battle Economist: ", item_name, " is FREE!")

	if player_coins < cost:
		print("SHOP→ Not enough coins for ", item_name)
		return false

	player_coins -= cost
	coins_changed.emit(player_coins)  # Emit signal for UI update
	
	match item_name:
		"hp_potion":
			party_inventory.hp_potion += 1
			print("SHOP→ Bought HP Potion (total: ", party_inventory.hp_potion, ")")
		"resolve_potion":
			party_inventory.resolve_potion += 1  
			print("SHOP→ Bought Resolve Potion (total: ", party_inventory.resolve_potion, ")")
		"power_boost":
			active_buffs.power_boost = true
			print("SHOP→ Bought Power Boost (2x damage next battle)")
		"quick_reflexes":
			active_buffs.quick_reflexes = true
			print("SHOP→ Bought Quick Reflexes (slower QTE windows next battle)")
		_:
			print("ERROR→ Unknown shop item: ", item_name)
			player_coins += cost  # Refund
			return false
	
	return true

# Upgrade functions (permanent improvements only)
func buy_upgrade(upgrade_name: String) -> bool:
	var cost = _get_upgrade_cost(upgrade_name)

	if player_coins < cost:
		print("UPGRADE→ Not enough coins for ", upgrade_name)
		return false

	player_coins -= cost
	coins_changed.emit(player_coins)  # Emit signal for UI update

	match upgrade_name:
		"iron_will", "berserker_might", "guardian_blessing", "battle_veteran", "legendary_resilience", "master_combatant", "unbreakable_will", "dual_wielding", "vampire_fang", "finishing_blow", "first_strike", "last_stand", "treasure_hunter", "battle_economist", "bloodlust", "weapon_master":
			# NOTE: This is the old single-purchase system for UpgradeOverlay compatibility
			# Upgrades now managed through new player_upgrades system
			print("UPGRADE→ Bought ", upgrade_name, " (legacy system - needs player assignment)")
		_:
			print("ERROR→ Unknown upgrade: ", upgrade_name)
			player_coins += cost  # Refund
			return false

	return true

func _get_upgrade_cost(upgrade_name: String) -> int:
	match upgrade_name:
		"iron_will": return 1
		"berserker_might": return 3
		"guardian_blessing": return 4
		"battle_veteran": return 4
		"legendary_resilience": return 5
		"master_combatant": return 6
		"unbreakable_will": return 5
		"dual_wielding": return 4
		"vampire_fang": return 6
		"finishing_blow": return 4
		"first_strike": return 3
		"last_stand": return 4
		"treasure_hunter": return 3
		"battle_economist": return 4
		"bloodlust": return 4
		"weapon_master": return 5
		_: return 1  # Default cost

# Player upgrade management functions
func assign_upgrade_to_player(upgrade_name: String, player_name: String):
	if player_name in player_upgrades:
		player_upgrades[player_name][upgrade_name] = true
		purchased_upgrades.append(upgrade_name)
		print("PROGRESS→ Assigned ", upgrade_name, " to ", player_name)
	else:
		print("ERROR→ Invalid player name: ", player_name)

func get_player_upgrades(player_name: String) -> Dictionary:
	if player_name in player_upgrades:
		return player_upgrades[player_name]
	return {}

func has_player_upgrade(player_name: String, upgrade_name: String) -> bool:
	if player_name in player_upgrades:
		return player_upgrades[player_name].get(upgrade_name, false)
	return false

func is_upgrade_purchased(upgrade_name: String) -> bool:
	return upgrade_name in purchased_upgrades

func get_player_upgrade_list(player_name: String) -> Array:
	var upgrades = get_player_upgrades(player_name)
	var upgrade_names = []
	for upgrade_name in upgrades:
		if upgrades[upgrade_name]:
			upgrade_names.append(upgrade_name.replace("_", " ").capitalize())
	return upgrade_names

# Battle flag functions for per-battle tracking
func set_battle_flag(flag_name: String, value: bool):
	battle_flags[flag_name] = value

func get_battle_flag(flag_name: String) -> bool:
	return battle_flags.get(flag_name, false)

func clear_battle_flags():
	print("PROGRESS→ Clearing battle flags: ", battle_flags)
	battle_flags.clear()
	print("PROGRESS→ Battle flags cleared for new battle")

func get_party_item_count(item_name: String) -> int:
	if item_name in party_inventory:
		return party_inventory[item_name]
	return 0

func use_party_item(item_name: String) -> bool:
	if get_party_item_count(item_name) > 0:
		party_inventory[item_name] -= 1
		print("PROGRESS→ Used ", item_name, " (remaining: ", party_inventory[item_name], ")")
		return true
	return false

# Apply and clear battle buffs
func apply_battle_buffs():
	print("PROGRESS→ Applying battle buffs...")

	# Clear battle flags for new battle (for First Strike, etc.)
	clear_battle_flags()
	
	# Apply Iron Will: +2 starting resolve (now per-player upgrade)
	if has_player_upgrade("Player1", "iron_will"):
		var player1_resolve = ResolveManager.get_resolve("Player1")
		ResolveManager.set_resolve("Player1", player1_resolve + 2)
		print("PROGRESS→ Iron Will applied to Player1: +2 resolve")

	if has_player_upgrade("Player2", "iron_will"):
		var player2_resolve = ResolveManager.get_resolve("Player2")
		ResolveManager.set_resolve("Player2", player2_resolve + 2)
		print("PROGRESS→ Iron Will applied to Player2: +2 resolve")

	# Apply Unbreakable Will: Start with maximum resolve (6)
	if has_player_upgrade("Player1", "unbreakable_will"):
		ResolveManager.set_resolve("Player1", 6)
		print("PROGRESS→ Unbreakable Will applied to Player1: set to max resolve (6)")

	if has_player_upgrade("Player2", "unbreakable_will"):
		ResolveManager.set_resolve("Player2", 6)
		print("PROGRESS→ Unbreakable Will applied to Player2: set to max resolve (6)")

	# Future buffs can be added here:
	# if active_buffs.power_boost:
	#     print("PROGRESS→ Power Boost applied: 2x damage this battle")
	# if active_buffs.quick_reflexes:
	#     print("PROGRESS→ Quick Reflexes applied: slower QTE windows")

func clear_battle_buffs():
	print("PROGRESS→ Clearing used battle buffs...")
	active_buffs.power_boost = false
	active_buffs.quick_reflexes = false
	# Note: iron_will is now a permanent upgrade, not cleared

# Enemy scaling based on battle progression
func get_enemy_hp_multiplier() -> float:
	match current_position:
		0: return 1.0    # Battle 1: 300 HP (100%)
		1: return 1.5    # Battle 2: 450 HP (150%) 
		2: return 2.0    # Battle 3: 600 HP (200%)
		_: return 2.0 + (current_position - 2) * 0.5  # Battle 4+: +50% each

func get_enemy_damage_multiplier() -> float:
	match current_position:
		0: return 1.0    # Battle 1: baseline damage (100%)
		1: return 1.5    # Battle 2: +50% damage (150%)
		2: return 2.0    # Battle 3: +100% damage (200%)
		_: return 2.0 + (current_position - 2) * 0.5  # Battle 4+: +50% each

func get_current_battle_number() -> int:
	return current_position + 1  # Convert 0-indexed to 1-indexed for display

# Progressive coin rewards based on battle difficulty
func get_battle_coin_reward() -> int:
	match current_position:
		0: return 10   # Battle 1: Tutorial Boss (was 5)
		1: return 20   # Battle 2: Shadow Beast (was 10)
		2: return 30   # Battle 3: Elite Guardian (was 15)
		3: return 40   # Battle 4: Ancient Warden (was 20)
		_: return 40   # Battle 5+: Final Boss (though game ends)

# Reset for new game
func reset_progress():
	current_position = 0
	player_coins = 0
	selected_path = ""
	party_inventory = {"hp_potion": 2, "resolve_potion": 2}
	active_buffs = {"power_boost": false, "quick_reflexes": false}
	coins_changed.emit(player_coins)  # Emit signal for UI update
	print("PROGRESS→ Progress reset to start")
