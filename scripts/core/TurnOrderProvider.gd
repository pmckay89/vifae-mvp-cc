extends RefCounted
class_name TurnOrderProvider

# Base interface for turn order providers
# Subclasses must implement get_round_order() to return ordered list of actors

# Interface method - must be overridden by subclasses
func get_round_order(actors: Array) -> Array[Node]:
	push_error("TurnOrderProvider.get_round_order() must be implemented by subclasses")
	return []

# Helper method to get actor by name from the actors array
func _get_actor_by_name(actors: Array, actor_name: String) -> Node:
	for actor in actors:
		if actor and actor.name == actor_name:
			return actor
	return null

# Helper method to filter out defeated actors (optional utility)
func _filter_active_actors(actors: Array) -> Array:
	var active_actors: Array = []
	for actor in actors:
		if actor and not actor.get("is_defeated", false):
			active_actors.append(actor)
	return active_actors

# ===== CONCRETE IMPLEMENTATIONS =====

# FixedOrderProvider - maintains current P1→P2→Enemy order
class FixedOrderProvider extends TurnOrderProvider:
	func get_round_order(actors: Array) -> Array[Node]:
		var ordered: Array[Node] = []
		
		# Return in fixed order: Player1 → Player2 → Enemy
		var player1 = _get_actor_by_name(actors, "Player1")
		var player2 = _get_actor_by_name(actors, "Player2") 
		var enemy = _get_actor_by_name(actors, "Enemy")
		
		if player1:
			ordered.append(player1)
		if player2:
			ordered.append(player2)
		if enemy:
			ordered.append(enemy)
			
		return ordered

# InitiativeOrderProvider - stub for speed/initiative-based ordering
class InitiativeOrderProvider extends TurnOrderProvider:
	func get_round_order(actors: Array) -> Array[Node]:
		# STUB: Would sort by initiative/speed stats
		# For now, just return the actors as-is (placeholder)
		print("[InitiativeOrderProvider] STUB - using default order")
		
		var ordered: Array[Node] = []
		for actor in actors:
			if actor:
				ordered.append(actor)
		return ordered

# ScriptedOrderProvider - stub for event-driven/scripted turn sequences  
class ScriptedOrderProvider extends TurnOrderProvider:
	var scripted_sequence: Array[String] = []
	var sequence_index: int = 0
	
	func set_sequence(sequence: Array[String]) -> void:
		scripted_sequence = sequence
		sequence_index = 0
	
	func get_round_order(actors: Array) -> Array[Node]:
		# STUB: Would follow a predetermined script sequence
		# For now, just return fixed order (placeholder)
		print("[ScriptedOrderProvider] STUB - using fixed order")
		
		var ordered: Array[Node] = []
		var player1 = _get_actor_by_name(actors, "Player1")
		var player2 = _get_actor_by_name(actors, "Player2")
		var enemy = _get_actor_by_name(actors, "Enemy")
		
		if player1:
			ordered.append(player1)
		if player2:
			ordered.append(player2)
		if enemy:
			ordered.append(enemy)
			
		return ordered