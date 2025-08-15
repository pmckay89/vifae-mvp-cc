extends Node

func take_turn(enemy_node):
	if enemy_node.is_defeated:
		print("[EnemyAI] Enemy is defeated. Skipping turn.")
		enemy_node.end_turn()
		return

	print("[EnemyAI] Deciding who to attack...")
	await get_tree().create_timer(0.5).timeout

	var players = [
		get_node("/root/BattleScene/Player1"),
		get_node("/root/BattleScene/Player2")
	]
	players = players.filter(func(p): return not p.is_defeated)

	if players.size() == 0:
		print("[EnemyAI] No valid targets.")
		enemy_node.end_turn()
		return

	var tm = get_node("/root/BattleScene/TurnManager")
	if tm.game_over:
		print("[EnemyAI] Game already over. Skipping attack.")
		enemy_node.end_turn()
		return

	var target = players[randi() % players.size()]
	print("[EnemyAI] Target selected:", target.name)
	enemy_node.attack(target)
