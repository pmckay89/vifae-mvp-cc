extends Node

# Save/Load game state management singleton
# MVP: Simple save system for single-boss battle

var save_file_path = "user://savegame.save"
var pending_save_data = {}

# MVP save data - just the essentials
var default_save_data = {
	"player1_hp": 100,
	"player1_resolve": 1,
	"player2_hp": 100,
	"player2_resolve": 1,
	"enemy_hp": 100,
	"current_turn": 1,
	"coins": 0,
	"current_scene": "BattleScene"
}

# TODO: Future expansions will include:
# - abilities_unlocked: []
# - potion_counts: {hp_potions: 3, resolve_potions: 1}
# - shop_upgrades: {damage_boost: false, defense_boost: false}
# - active_buffs: [{type: "strength", duration: 3}]
# - status_effects: {player1: [], player2: [], enemy: []}
# - battle_phase: "SHOW_MENU"
# - enemy_patterns_used: []
# - weapon_upgrades: {}
# - character_levels: {player1: 1, player2: 1}

func save_game() -> bool:
	print("[SaveManager] Saving game...")

	var save_data = collect_current_game_data()
	print("[SaveManager] Save data: ", save_data)

	var save_file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if save_file == null:
		print("[SaveManager] ERROR: Could not open save file for writing")
		return false

	save_file.store_string(JSON.stringify(save_data))
	save_file.close()

	print("[SaveManager] Game saved successfully")
	return true

func load_game() -> Dictionary:
	print("[SaveManager] Loading game...")

	if not FileAccess.file_exists(save_file_path):
		print("[SaveManager] No save file found")
		return {}

	var save_file = FileAccess.open(save_file_path, FileAccess.READ)
	if save_file == null:
		print("[SaveManager] ERROR: Could not open save file for reading")
		return {}

	var save_string = save_file.get_as_text()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(save_string)

	if parse_result != OK:
		print("[SaveManager] ERROR: Save file corrupted")
		return {}

	var save_data = json.data
	print("[SaveManager] Loaded data: ", save_data)
	print("[SaveManager] Game loaded successfully")
	return save_data

func has_save_file() -> bool:
	return FileAccess.file_exists(save_file_path)

func delete_save_file():
	if FileAccess.file_exists(save_file_path):
		DirAccess.remove_absolute(save_file_path)
		print("[SaveManager] Save file deleted")

# Collect current game state from active nodes
func collect_current_game_data() -> Dictionary:
	var data = default_save_data.duplicate()

	# Try to get current game state from battle scene
	var battle_scene = get_node_or_null("/root/BattleScene")
	if battle_scene:
		# Get player data
		var player1 = get_node_or_null("/root/BattleScene/Player1")
		if player1:
			if player1.has_method("get_current_hp"):
				data.player1_hp = player1.get_current_hp()
			if player1.has_method("get_resolve"):
				data.player1_resolve = player1.get_resolve()

		var player2 = get_node_or_null("/root/BattleScene/Player2")
		if player2:
			if player2.has_method("get_current_hp"):
				data.player2_hp = player2.get_current_hp()
			if player2.has_method("get_resolve"):
				data.player2_resolve = player2.get_resolve()

		# Get enemy data
		var enemy = get_node_or_null("/root/BattleScene/Enemy")
		if enemy and enemy.has_method("get_current_hp"):
			data.enemy_hp = enemy.get_current_hp()

		# Get turn manager data
		var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
		if turn_manager:
			if turn_manager.has_method("get_current_turn"):
				data.current_turn = turn_manager.get_current_turn()
			# TODO: Add coin tracking when implemented

		data.current_scene = "BattleScene"

	return data

# Apply loaded save data to current scene
func apply_save_data(save_data: Dictionary):
	print("[SaveManager] Applying save data...")

	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		print("[SaveManager] ERROR: BattleScene not found")
		return

	# Apply player data
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	if player1:
		if player1.has_method("set_hp"):
			player1.set_hp(save_data.get("player1_hp", 100))
		if player1.has_method("set_resolve"):
			player1.set_resolve(save_data.get("player1_resolve", 1))

	var player2 = get_node_or_null("/root/BattleScene/Player2")
	if player2:
		if player2.has_method("set_hp"):
			player2.set_hp(save_data.get("player2_hp", 100))
		if player2.has_method("set_resolve"):
			player2.set_resolve(save_data.get("player2_resolve", 1))

	# Apply enemy data
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("set_hp"):
		enemy.set_hp(save_data.get("enemy_hp", 100))

	# Apply turn manager data
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	if turn_manager and turn_manager.has_method("set_current_turn"):
		turn_manager.set_current_turn(save_data.get("current_turn", 1))

	# TODO: Apply coins, abilities, potions, etc. when implemented

	# Update UI to reflect loaded values
	_refresh_ui_displays()

	print("[SaveManager] Save data applied")

func _refresh_ui_displays():
	print("[SaveManager] Refreshing UI displays...")

	# Refresh HP displays for players
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	var player2 = get_node_or_null("/root/BattleScene/Player2")
	var enemy = get_node_or_null("/root/BattleScene/Enemy")

	# Update HP bars and labels
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	if turn_manager:
		if turn_manager.has_method("_initialize_hp_displays"):
			turn_manager._initialize_hp_displays()

		# Force enemy HP bar update specifically
		if enemy and enemy.has_method("get_current_hp"):
			var enemy_hp = enemy.get_current_hp()
			var enemy_hp_max = enemy.hp_max if "hp_max" in enemy else 300

			# Update both label and progress bar for enemy
			CombatUI.update_hp_bar("Enemy", enemy_hp, enemy_hp_max)

			# Also directly update the progress bar since CombatUI doesn't do it for enemies
			var enemy_hp_bar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
			if enemy_hp_bar:
				enemy_hp_bar.max_value = enemy_hp_max
				enemy_hp_bar.value = enemy_hp
				print("[SaveManager] Updated Enemy HP bar progress: ", enemy_hp, "/", enemy_hp_max)
			else:
				print("[SaveManager] Could not find Enemy HP bar!")

			print("[SaveManager] Force updated Enemy HP display: ", enemy_hp, "/", enemy_hp_max)

		if turn_manager.has_method("update_resolve_display"):
			turn_manager.update_resolve_display("Player1")
			turn_manager.update_resolve_display("Player2")
		if turn_manager.has_method("update_coin_display"):
			turn_manager.update_coin_display()

	print("[SaveManager] UI displays refreshed")

func _ready():
	# Don't auto-apply here - let BattleScene call us when ready
	pass

func check_and_apply_pending_save():
	if not pending_save_data.is_empty():
		print("[SaveManager] Applying pending save data...")
		apply_save_data(pending_save_data)
		pending_save_data = {}  # Clear after applying
		return true
	return false