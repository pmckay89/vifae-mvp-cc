extends Node

# Save/Load game state management singleton
# MVP: Simple save system for single-boss battle

var save_file_path = "user://savegame.save"
var pending_save_data = {}

# Expanded save data - includes all progression systems
var default_save_data = {
	"player1_hp": 100,
	"player1_resolve": 1,
	"player2_hp": 100,
	"player2_resolve": 1,
	"enemy_hp": 100,
	"enemy_hp_max": 300,
	"current_turn": 1,
	"current_scene": "BattleScene",
	# ProgressManager data
	"progress_data": {},
	# StatusEffectManager data (from all entities)
	"player1_status_effects": [],
	"player2_status_effects": [],
	"enemy_status_effects": []
}

# Expanded save system now includes:
# ✅ Items/inventory (party_inventory)
# ✅ Player upgrades (player_upgrades)
# ✅ Player abilities (player_abilities)
# ✅ Progression tracking (current_position, purchased_upgrades/abilities)
# ✅ Active status effects (active_effects for all entities)
# ✅ Battle flags and buffs

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
		# Get player data (HP and resolve)
		var player1 = get_node_or_null("/root/BattleScene/Player1")
		if player1:
			data.player1_hp = player1.hp if "hp" in player1 else 100

		var player2 = get_node_or_null("/root/BattleScene/Player2")
		if player2:
			data.player2_hp = player2.hp if "hp" in player2 else 100

		# Get resolve from ResolveManager
		var resolve_manager = get_node_or_null("/root/ResolveManager")
		if resolve_manager:
			data.player1_resolve = resolve_manager.player1_resolve
			data.player2_resolve = resolve_manager.player2_resolve
		else:
			data.player1_resolve = 1
			data.player2_resolve = 1

		# Get enemy data
		var enemy = get_node_or_null("/root/BattleScene/Enemy")
		if enemy:
			data.enemy_hp = enemy.hp if "hp" in enemy else 100
			data.enemy_hp_max = enemy.hp_max if "hp_max" in enemy else 300

		# Get turn manager data
		var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
		if turn_manager and turn_manager.has_method("get_current_turn"):
			data.current_turn = turn_manager.get_current_turn()
		else:
			data.current_turn = 1

		data.current_scene = "BattleScene"

	# Get ProgressManager data (items, upgrades, abilities, progression)
	if ProgressManager:
		data.progress_data = ProgressManager.get_save_data()
		print("[SaveManager] Collected ProgressManager data: ", data.progress_data.keys())

	# Get StatusEffects data from each entity
	var player1 = get_node_or_null("/root/BattleScene/Player1/StatusEffects")
	if player1:
		data.player1_status_effects = player1.get_save_data()

	var player2 = get_node_or_null("/root/BattleScene/Player2/StatusEffects")
	if player2:
		data.player2_status_effects = player2.get_save_data()

	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("get_node") and enemy.get_node_or_null("StatusEffects"):
		data.enemy_status_effects = enemy.get_node("StatusEffects").get_save_data()
	else:
		data.enemy_status_effects = []

	print("[SaveManager] Collected ", data.player1_status_effects.size(), " P1 effects, ", data.player2_status_effects.size(), " P2 effects")
	return data

# Apply loaded save data to current scene
func apply_save_data(save_data: Dictionary):
	print("[SaveManager] Applying save data...")

	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		print("[SaveManager] ERROR: BattleScene not found")
		return

	# Apply ProgressManager data first (items, upgrades, abilities, progression)
	if save_data.has("progress_data") and ProgressManager:
		ProgressManager.load_save_data(save_data.progress_data)
		print("[SaveManager] Applied ProgressManager data")

	# Apply player data (HP only)
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	if player1:
		player1.hp = int(save_data.get("player1_hp", 100))

	var player2 = get_node_or_null("/root/BattleScene/Player2")
	if player2:
		player2.hp = int(save_data.get("player2_hp", 100))

	# Apply resolve via ResolveManager
	var resolve_manager = get_node_or_null("/root/ResolveManager")
	if resolve_manager:
		resolve_manager.player1_resolve = int(save_data.get("player1_resolve", 1))
		resolve_manager.player2_resolve = int(save_data.get("player2_resolve", 1))

	# Apply enemy data
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy:
		enemy.hp = int(save_data.get("enemy_hp", 100))
		enemy.hp_max = int(save_data.get("enemy_hp_max", 300))

	# Apply turn manager data
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	if turn_manager and turn_manager.has_method("set_current_turn"):
		turn_manager.set_current_turn(int(save_data.get("current_turn", 1)))

	# Apply status effects to each entity
	var player1_status = get_node_or_null("/root/BattleScene/Player1/StatusEffects")
	if player1_status and save_data.has("player1_status_effects"):
		player1_status.load_save_data(save_data.player1_status_effects)

	var player2_status = get_node_or_null("/root/BattleScene/Player2/StatusEffects")
	if player2_status and save_data.has("player2_status_effects"):
		player2_status.load_save_data(save_data.player2_status_effects)

	var enemy_status = get_node_or_null("/root/BattleScene/Enemy")
	if enemy_status and enemy_status.get_node_or_null("StatusEffects") and save_data.has("enemy_status_effects"):
		enemy_status.get_node("StatusEffects").load_save_data(save_data.enemy_status_effects)

	print("[SaveManager] Applied status effects to all entities")

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
		if enemy:
			var enemy_hp = enemy.hp if "hp" in enemy else 100
			var enemy_hp_max = enemy.hp_max if "hp_max" in enemy else 300

			# Update both label and progress bar for enemy
			CombatUI.update_hp_bar("Enemy", enemy_hp, enemy_hp_max)
			print("[SaveManager] Updated Enemy HP display: ", enemy_hp, "/", enemy_hp_max)

			# Force update the progress bar directly to ensure it shows correct values
			var enemy_hp_bar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
			if enemy_hp_bar:
				enemy_hp_bar.max_value = enemy_hp_max
				enemy_hp_bar.value = enemy_hp
				print("[SaveManager] Directly updated Enemy HP bar: ", enemy_hp, "/", enemy_hp_max)

			# Also update enemy label directly
			var enemy_hp_label = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel")
			if enemy_hp_label:
				enemy_hp_label.text = str(enemy_hp) + " / " + str(enemy_hp_max)
				print("[SaveManager] Updated Enemy HP label: ", enemy_hp_label.text)

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
