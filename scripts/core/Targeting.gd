extends RefCounted
class_name Targeting

# Centralized targeting helpers for enemy AI and general combat targeting

# Get all players that are alive (not defeated)
static func alive_players(players: Array) -> Array:
	var alive: Array = []
	for player in players:
		if player and not (player.get("is_defeated") if "is_defeated" in player else false):
			alive.append(player)
	return alive

# Get a random alive player from the list
static func random_player(players: Array) -> Node:
	var alive = alive_players(players)
	if alive.size() == 0:
		return null
	return alive[randi() % alive.size()]

# Get the alive player with the lowest HP
static func lowest_hp_player(players: Array) -> Node:
	var alive = alive_players(players)
	if alive.size() == 0:
		return null
	
	var lowest_player = alive[0]
	var lowest_hp = lowest_player.get("hp") if "hp" in lowest_player else 999999
	
	for player in alive:
		var player_hp = player.get("hp") if "hp" in player else 999999
		if player_hp < lowest_hp:
			lowest_hp = player_hp
			lowest_player = player
	
	return lowest_player

# Get the alive player with the highest HP (for strategic targeting)
static func highest_hp_player(players: Array) -> Node:
	var alive = alive_players(players)
	if alive.size() == 0:
		return null
	
	var highest_player = alive[0]
	var highest_hp = highest_player.get("hp") if "hp" in highest_player else 0
	
	for player in alive:
		var player_hp = player.get("hp") if "hp" in player else 0
		if player_hp > highest_hp:
			highest_hp = player_hp
			highest_player = player
	
	return highest_player

# Check if any players in the list are alive
static func has_alive_players(players: Array) -> bool:
	return alive_players(players).size() > 0

# Get alive player count
static func alive_player_count(players: Array) -> int:
	return alive_players(players).size()

# Get all players (alive and defeated) with their status
static func get_player_status(players: Array) -> Array:
	var status: Array = []
	for player in players:
		if player:
			status.append({
				"name": player.name,
				"hp": player.get("hp") if "hp" in player else 0,
				"max_hp": player.get("hp_max") if "hp_max" in player else 100,
				"is_defeated": player.get("is_defeated") if "is_defeated" in player else false
			})
	return status

# Debug helper - print current targeting state
static func debug_targeting_state(players: Array, context: String = "") -> void:
	var alive = alive_players(players)
	var context_str = " (" + context + ")" if context != "" else ""
	
	print("[Targeting] State" + context_str + ":")
	print("  → Total players: ", players.size())
	print("  → Alive players: ", alive.size())
	
	for player in players:
		if player:
			var status = "ALIVE" if not (player.get("is_defeated") if "is_defeated" in player else false) else "DEFEATED"
			var hp = player.get("hp") if "hp" in player else 0
			var max_hp = player.get("hp_max") if "hp_max" in player else 100
			print("    • ", player.name, ": ", hp, "/", max_hp, " HP (", status, ")")
	
	if alive.size() > 0:
		var random = random_player(players)
		var lowest = lowest_hp_player(players)
		var highest = highest_hp_player(players)
		
		print("  → Random target: ", random.name if random else "none")
		print("  → Lowest HP: ", lowest.name if lowest else "none", " (", (lowest.get("hp") if "hp" in lowest else 0) if lowest else 0, " HP)")
		print("  → Highest HP: ", highest.name if highest else "none", " (", (highest.get("hp") if "hp" in highest else 0) if highest else 0, " HP)")
	else:
		print("  → No valid targets available")
