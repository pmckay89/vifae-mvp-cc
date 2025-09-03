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

# Shared party inventory (simplified from per-player)
var party_inventory = {
	"hp_potion": 2,        # Start with 2 HP potions
	"resolve_potion": 2     # Start with 2 Resolve potions
}

# Temporary battle buffs from shop
var active_buffs = {
	"power_boost": false,     # 2x damage next battle
	"quick_reflexes": false,  # Slower QTE windows next battle  
	"iron_will": false        # +2 resolve start next battle
}

# Map structure: array of fork choices (what comes after each battle)
var map_structure = [
	{"battle_name": "Tutorial Boss", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE},
	{"battle_name": "Shadow Beast", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE}, 
	{"battle_name": "Final Boss", "fork_a": NodeType.SHOP, "fork_b": NodeType.UPGRADE}
]

var selected_path: String = ""  # "A" or "B" - tracks player's last choice

func _ready():
	print("PROGRESS→ ProgressManager initialized")
	print("PROGRESS→ Starting coins: ", player_coins)

# Called after battle victory
func complete_battle():
	var coins_earned = 25  # Placeholder - could vary by battle difficulty
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
	var cost = 1  # All upgrades cost 1 coin
	
	if player_coins < cost:
		print("UPGRADE→ Not enough coins for ", upgrade_name)
		return false
	
	player_coins -= cost
	coins_changed.emit(player_coins)  # Emit signal for UI update
	
	match upgrade_name:
		"iron_will":
			active_buffs.iron_will = true
			print("UPGRADE→ Bought Iron Will (permanent +2 starting resolve)")
		_:
			print("ERROR→ Unknown upgrade: ", upgrade_name)
			player_coins += cost  # Refund
			return false
	
	return true

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
	
	# Apply Iron Will: +2 starting resolve for both players
	if active_buffs.iron_will:
		var player1_resolve = ResolveManager.get_resolve("Player1")
		var player2_resolve = ResolveManager.get_resolve("Player2")
		
		ResolveManager.set_resolve("Player1", player1_resolve + 2)
		ResolveManager.set_resolve("Player2", player2_resolve + 2)
		
		print("PROGRESS→ Iron Will applied: +2 resolve to both players")
	
	# Future buffs can be added here:
	# if active_buffs.power_boost:
	#     print("PROGRESS→ Power Boost applied: 2x damage this battle")
	# if active_buffs.quick_reflexes:
	#     print("PROGRESS→ Quick Reflexes applied: slower QTE windows")

func clear_battle_buffs():
	print("PROGRESS→ Clearing used battle buffs...")
	active_buffs.power_boost = false
	active_buffs.quick_reflexes = false
	active_buffs.iron_will = false

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

# Reset for new game
func reset_progress():
	current_position = 0
	player_coins = 0
	selected_path = ""
	party_inventory = {"hp_potion": 2, "resolve_potion": 2}
	active_buffs = {"power_boost": false, "quick_reflexes": false, "iron_will": false}
	coins_changed.emit(player_coins)  # Emit signal for UI update
	print("PROGRESS→ Progress reset to start")
