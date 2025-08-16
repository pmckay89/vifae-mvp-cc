extends Node

const TurnOrderProvider = preload("res://scripts/core/TurnOrderProvider.gd")

# MVP State Machine - Strict Input Split
enum State {
	BEGIN_TURN,
	ACTOR_READY,
	SHOW_MENU,
	ENEMY_THINK,
	QTE_ACTIVE,
	RESOLVE_ACTION,
	CHECK_END,
	VICTORY,
	GAME_OVER,
	RESET_COMBAT
}

var current_state: State = State.BEGIN_TURN
var turn_order: Array = []
var current_turn_index: int = 0
var current_actor: Node = null
var selected_action: String = ""
var selected_target: Node = null
var enemy_attack_count: int = 0
const GAME_OVER_THEME = "res://assets/music/closer.wav"

# UI References - match your exact paths
@onready var turn_label := get_node("../UILayer/TurnLabel")
@onready var action_menu := get_node_or_null("/root/BattleScene/UILayer/ActionMenu")
@onready var attack_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/AttackButton")
@onready var skills_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/SkillsButton")
@onready var skills_menu := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu")
@onready var twocut_button := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu/TwoCutButton")
@onready var bigshot_button := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu/BigShotButton")
@onready var bgm_player := get_node("../BGMPlayer")
@onready var result_overlay := get_node_or_null("/root/BattleScene/UILayer/ResultOverlay")
@onready var pause_overlay := get_node_or_null("/root/BattleScene/UILayer/PauseOverlay")

# Menu state
var menu_selection: int = 0
var in_skills_menu: bool = false
var skill_selection: int = 0  # For cycling through skills
var music_enabled: bool = true

# Turn order provider system
var turn_order_provider: TurnOrderProvider

# Usage examples for switching providers:
# set_turn_order_provider(TurnOrderProvider.FixedOrderProvider.new())       # P1→P2→Enemy (default)
# set_turn_order_provider(TurnOrderProvider.InitiativeOrderProvider.new())  # Speed-based (stub)
# set_turn_order_provider(TurnOrderProvider.ScriptedOrderProvider.new())    # Event-driven (stub)

func _ready():
	AudioServer.set_bus_volume_db(0, -6.0)  # Force Master bus loud
	print("STATE→ INITIALIZING TurnManager")
	
	# Initialize turn order provider (default: fixed order)
	turn_order_provider = TurnOrderProvider.FixedOrderProvider.new()
	
	# Set up turn order using provider
	var all_actors = [
		get_node("/root/BattleScene/Player1"),
		get_node("/root/BattleScene/Player2"), 
		get_node("/root/BattleScene/Enemy")
	]
	turn_order = turn_order_provider.get_round_order(all_actors)
	
	var actor_names = []
	for actor in turn_order:
		actor_names.append(actor.name)
	print("STATE→ Turn order established: ", actor_names)
	
	# Start the state machine
	change_state(State.BEGIN_TURN)

func _input(event):
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	
	# Pause toggle (works during any state except result overlay)
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
		if result_overlay and result_overlay.visible:
			return  # Don't allow pause during result overlay
		toggle_pause()
		return
	
	# Skip input if any overlay is showing
	if (result_overlay and result_overlay.visible) or (pause_overlay and pause_overlay.visible):
		return
	
	# Music toggle
	if event.keycode == KEY_M:
		toggle_music()
		return
		
	match current_state:
		State.SHOW_MENU:
			handle_menu_input(event)
		State.QTE_ACTIVE:
			# QTE handles its own input, we just log
			if event.is_action_pressed("confirm attack"):
				print("INPUT→ Z pressed during QTE (offense)")
			elif event.is_action_pressed("parry"):
				print("INPUT→ X pressed during QTE (defense)")

func handle_menu_input(event):
	if in_skills_menu:
		handle_skills_menu_input(event)
	else:
		handle_action_menu_input(event)

func handle_action_menu_input(event):
	if event.is_action_pressed("move up"):
		menu_selection = max(0, menu_selection - 1)
		update_menu_highlight()
		_safe_audio_call("play_ui_move")
		print("MENU→ Selection: " + str(menu_selection))
		
	elif event.is_action_pressed("move down"):
		menu_selection = min(1, menu_selection + 1)  # Attack=0, Skills=1
		update_menu_highlight()
		_safe_audio_call("play_ui_move")
		print("MENU→ Selection: " + str(menu_selection))
		
	elif event.is_action_pressed("confirm attack"):  # Z confirms
		_safe_audio_call("play_ui_confirm")
		if menu_selection == 0:
			selected_action = "attack"
			selected_target = get_enemy()
			if selected_target == null:
				print("ERROR→ No enemy target found!")
				return
			print("MENU→ Attack selected")
			change_state(State.QTE_ACTIVE)
		elif menu_selection == 1:
			print("MENU→ Opening Skills submenu")
			open_skills_menu()
			
	elif event.is_action_pressed("cancel dodge"):  # C cancels
		print("MENU→ Cancel pressed (no effect at top level)")

func handle_skills_menu_input(event):
	if event.is_action_pressed("move up"):
		var abilities = current_actor.get_ability_list() if current_actor.has_method("get_ability_list") else []
		if abilities.size() > 1:
			skill_selection = (skill_selection - 1 + abilities.size()) % abilities.size()
			update_skills_menu_display()
			_safe_audio_call("play_ui_move")
			print("MENU→ Skill selection: " + str(skill_selection))
		
	elif event.is_action_pressed("move down"):
		var abilities = current_actor.get_ability_list() if current_actor.has_method("get_ability_list") else []
		if abilities.size() > 1:
			skill_selection = (skill_selection + 1) % abilities.size()
			update_skills_menu_display()
			_safe_audio_call("play_ui_move")
			print("MENU→ Skill selection: " + str(skill_selection))
		
	elif event.is_action_pressed("confirm attack"):  # Z confirms skill selection
		_safe_audio_call("play_ui_confirm")
		var abilities = current_actor.get_ability_list() if current_actor.has_method("get_ability_list") else []
		if abilities.size() > skill_selection:
			selected_action = abilities[skill_selection]
			var display_name = current_actor.get_ability_display_name(selected_action) if current_actor.has_method("get_ability_display_name") else selected_action
			print("MENU→ " + display_name + " selected")
		else:
			# Fallback to old system
			if current_actor.name == "Player1":
				selected_action = "2x_cut"
				print("MENU→ 2x Cut selected")
			elif current_actor.name == "Player2":
				selected_action = "big_shot"
				print("MENU→ Big Shot selected")
		
		selected_target = get_enemy()
		if selected_target == null:
			print("ERROR→ No enemy target found!")
			close_skills_menu()
			return
		close_skills_menu()
		change_state(State.QTE_ACTIVE)
		
	elif event.is_action_pressed("cancel dodge"):  # C backs out
		print("MENU→ Backing out of Skills menu")
		close_skills_menu()

func open_skills_menu():
	_safe_audio_call("play_ui_confirm")  # Play sound when opening skills menu
	in_skills_menu = true
	skill_selection = 0  # Reset to first skill
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = true
	
	update_skills_menu_display()

func update_skills_menu_display():
	# Get current actor's abilities
	var abilities = current_actor.get_ability_list() if current_actor.has_method("get_ability_list") else []
	
	if abilities.size() == 0:
		# Fallback - hide both buttons
		if twocut_button:
			twocut_button.visible = false
		if bigshot_button:
			bigshot_button.visible = false
		return
	
	# Clear existing text and setup for list display
	var skills_text = ""
	for i in range(abilities.size()):
		var ability = abilities[i]
		var display_name = current_actor.get_ability_display_name(ability) if current_actor.has_method("get_ability_display_name") else ability
		
		# Add selection indicator for current skill
		if i == skill_selection:
			skills_text += "→ " + display_name + " ←\n"
		else:
			skills_text += "  " + display_name + "\n"
	
	# Display all skills in the first button, hide the second
	if twocut_button:
		twocut_button.visible = true
		twocut_button.text = skills_text.strip_edges()
		twocut_button.grab_focus()
	if bigshot_button:
		bigshot_button.visible = false

func close_skills_menu():
	in_skills_menu = false
	if skills_menu:
		skills_menu.visible = false
	# Hide both skill buttons
	if twocut_button:
		twocut_button.visible = false
	if bigshot_button:
		bigshot_button.visible = false
	if action_menu:
		action_menu.visible = true
	update_menu_highlight()

func update_menu_highlight():
	# Simple highlighting using button focus
	if attack_button and skills_button:
		if menu_selection == 0:
			attack_button.grab_focus()
		else:
			skills_button.grab_focus()

func change_state(new_state: State):
	print("STATE→ " + State.keys()[current_state] + " -> " + State.keys()[new_state])
	current_state = new_state
	
	match current_state:
		State.BEGIN_TURN:
			begin_turn()
		State.ACTOR_READY:
			actor_ready()
		State.SHOW_MENU:
			show_menu()
		State.ENEMY_THINK:
			enemy_think()
		State.QTE_ACTIVE:
			start_qte()
		State.RESOLVE_ACTION:
			resolve_action()
		State.CHECK_END:
			check_end()
		State.VICTORY:
			victory()
		State.GAME_OVER:
			game_over()
		State.RESET_COMBAT:
			reset_combat()

func begin_turn():
	current_actor = turn_order[current_turn_index]
	print("STATE→ BEGIN_TURN: " + current_actor.name)
	
	# Skip defeated actors
	if current_actor.get("is_defeated"):
		print("STATE→ Actor defeated, skipping")
		end_turn()
		return
		
	change_state(State.ACTOR_READY)

func actor_ready():
	print("STATE→ ACTOR_READY: " + current_actor.name)
	
	if turn_label:
		turn_label.text = current_actor.name + "'s Turn"
	
	if is_player(current_actor):
		change_state(State.SHOW_MENU)
	else:
		change_state(State.ENEMY_THINK)

func show_menu():
	print("STATE→ SHOW_MENU for " + current_actor.name)
	menu_selection = 0
	in_skills_menu = false
	
	if action_menu:
		action_menu.visible = true
	if skills_menu:
		skills_menu.visible = false
		
	update_menu_highlight()

func enemy_think():
	print("STATE→ ENEMY_THINK")
	
	
	# Hide any player menus
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
		
	# Brief delay for enemy "thinking"
	await get_tree().create_timer(1.0).timeout
	
	# Enemy selects attack and target
	selected_target = get_random_alive_player()
	if selected_target == null:
		print("STATE→ No valid targets, ending turn")
		end_turn()
		return
		
	# Determine enemy attack pattern (deterministic rotation)
	var attack_index = enemy_attack_count % 3
	print("DEBUG→ Enemy attack count: " + str(enemy_attack_count))
	print("DEBUG→ Attack index: " + str(attack_index))
	enemy_attack_count += 1  # Increment for next time
	
	match attack_index:
		0:
			selected_action = "arc_slash"
			print("ENEMY→ Arc Slash (single-tap QTE)")
		1:
			selected_action = "lightning_surge" 
			print("ENEMY→ Lightning Surge (multi-tap QTE)")
		2:
			selected_action = "phase_slam"
			print("ENEMY→ Phase Slam (hold QTE)")
	
	change_state(State.QTE_ACTIVE)

func start_qte():
	print("STATE→ QTE_ACTIVE")
	
	var qte_result: String
	
	if is_player(current_actor):
		# Small delay to prevent menu input carryover
		await get_tree().create_timer(1.0).timeout
		
		# Player offense - let player handle their own abilities
		if selected_action == "attack":
			# Basic attack uses simple QTE
			qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z to attack!", current_actor)
		else:
			# All abilities use the player's ability system
			if current_actor.has_method("execute_ability") and selected_target:
				await current_actor.execute_ability(selected_action, selected_target)
				qte_result = "handled"  # Flag that player handled it
			else:
				# Fallback
				qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z!", current_actor)
	else:
		# Enemy attack - subtle shift toward defender 1 second before attack
		var battle_camera = get_node_or_null("/root/BattleScene/BattleCamera")
		if battle_camera and battle_camera.has_method("zoom_to_target") and selected_target:
			print("🎥 Subtle camera shift toward defender: " + selected_target.name)
			battle_camera.zoom_to_target(selected_target, 1.02, 0.3)
		
		# Play incoming attack warning sound
		var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/incoming.wav")
			sfx_player.play()
			print("🚨 Playing incoming attack warning")
		
		# Wait 1 second (zoom completes + dramatic pause)
		await get_tree().create_timer(1.0).timeout
		
		# Enemy attack QTE (X button for defense)
		match selected_action:
			"arc_slash":
				qte_result = await QTEManager.start_qte("parry", 700, "Press X to parry!", selected_target)
			"lightning_surge":
				qte_result = await QTEManager.start_qte("parry", 500, "Press X rapidly!", selected_target)
			"phase_slam":
				qte_result = await QTEManager.start_qte("parry", 900, "Hold X, release on cue!", selected_target)
	
	print("QTE→ Result: " + qte_result)
	
	# Store result for resolve phase
	set_meta("qte_result", qte_result)
	change_state(State.RESOLVE_ACTION)

func resolve_action():
	print("STATE→ RESOLVE_ACTION")
	
	var qte_result = get_meta("qte_result", "fail")
	var damage = 0
	
	if is_player(current_actor):
		# Player action damage
		if qte_result == "handled":
			# Player already handled damage through their ability system
			print("DMG→ Player ability " + selected_action + " handled by player system")
		elif selected_action == "attack":
			# Only basic attack uses TurnManager damage calculation
			match qte_result:
				"crit": damage = 10
				"normal": damage = 6
				"fail": damage = 0
			var target_name = "null target"
			if selected_target:
				target_name = selected_target.name
			print("DMG→ Player deals " + str(damage) + " to " + target_name)
			if damage > 0 and selected_target and selected_target.has_method("take_damage"):
				selected_target.take_damage(damage)
		else:
			print("WARNING→ Unhandled player action: " + selected_action)
			
	else:
		# Enemy action damage (mitigated by parry)
		var base_damage = 0
		match selected_action:
			"arc_slash": base_damage = 100
			"lightning_surge": base_damage = 120  # 6+6
			"phase_slam": base_damage = 180
			
		# Show enemy attack animation
		if current_actor.has_method("attack_animation"):
			current_actor.attack_animation(selected_target)
			
		# ADD THIS LINE - delay to see the animation
		await get_tree().create_timer(0.8).timeout
			
		# Apply parry mitigation
		var mitigation = 0.0
		match qte_result:
			"normal": mitigation = 1.0   # 0% damage (successful parry)
			"fail": mitigation = 0.0     # 100% damage (failed parry)
			
		damage = int(base_damage * (1.0 - mitigation))
		print("DMG→ Enemy deals " + str(damage) + " to " + selected_target.name + " (base: " + str(base_damage) + ", mitigated: " + str(int(mitigation * 100)) + "%)")
		
		if damage > 0 and selected_target.has_method("take_damage"):
			selected_target.take_damage(damage)
			
		# Hide enemy attack animation after damage
		if current_actor.has_method("end_attack_animation"):
			current_actor.end_attack_animation()
		
		# Zoom out after attack/VFX ends (only for enemy attacks)
		var battle_camera = get_node_or_null("/root/BattleScene/BattleCamera")
		if battle_camera and battle_camera.has_method("zoom_to_original"):
			print("🎥 Zooming out after enemy attack")
			battle_camera.zoom_to_original(0.3)
	
	# Add feedback here (screen shake, hitstop, etc.)
	trigger_feedback(qte_result, damage)
	
	change_state(State.CHECK_END)

func trigger_feedback(qte_result: String, damage: int):
	# Placeholder for feedback system
	print("FEEDBACK→ " + qte_result + " result, " + str(damage) + " damage")
	# TODO: Screen shake, hitstop, popup, etc.

func check_end():
	print("STATE→ CHECK_END")
	
	# Check victory (all enemies defeated)
	var enemies_alive = false
	for actor in turn_order:
		if actor.name.begins_with("Enemy") and not actor.get("is_defeated"):
			enemies_alive = true
			break
			
	if not enemies_alive:
		print("CHECK→ Victory condition met")
		change_state(State.VICTORY)
		return
	
	# Check defeat (all players defeated)  
	var players_alive = false
	for actor in turn_order:
		if is_player(actor) and not actor.get("is_defeated"):
			players_alive = true
			break
			
	if not players_alive:
		print("CHECK→ Defeat condition met")
		change_state(State.GAME_OVER)
		return
		
	# Continue combat
	print("CHECK→ Combat continues")
	end_turn()

func victory():
	print("STATE→ VICTORY")
	if turn_label:
		turn_label.text = "VICTORY!"
		
	# Hide menus
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
	
	# Show result overlay instead of auto-reset
	show_result_overlay("victory")

func game_over():
	print("STATE→ GAME_OVER") 
	if turn_label:
		turn_label.text = "DEFEAT..."
		
	# Hide menus
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
	
	# Fade out current BGM and play game over music
	if bgm_player and bgm_player.playing:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -60, 0.6)
		await tween.finished
		bgm_player.stop()
	
	# Play game over music
	var game_over_audio = AudioStreamPlayer.new()
	add_child(game_over_audio)
	game_over_audio.stream = load(GAME_OVER_THEME)
	game_over_audio.volume_db = -6
	game_over_audio.play()
	
	# Clean up audio after playing
	game_over_audio.finished.connect(func(): game_over_audio.queue_free())
	
	# Show result overlay
	show_result_overlay("defeat")

func show_result_overlay(mode: String):
	print("TURNMGR→ Showing result overlay: " + mode)
	if result_overlay and result_overlay.has_method("show_result"):
		result_overlay.show_result(mode)
	else:
		print("ERROR→ ResultOverlay not found or missing show_result method")

func reset_combat():
	print("RESET→ Resetting combat to initial state")
	
	# Reset all actors properly
	for actor in turn_order:
		if actor.has_method("reset_for_new_combat"):
			actor.reset_for_new_combat()
		else:
			# Default reset for players
			actor.hp = actor.hp_max
			actor.is_defeated = false
			print("RESET→ " + actor.name + " HP reset to " + str(actor.hp_max))
	
	# Force HP bar updates
	CombatUI.update_hp_bar("Player1", 50, 50)
	CombatUI.update_hp_bar("Player2", 50, 50) 
	CombatUI.update_hp_bar("Enemy", 150, 150)
	
	# Reset turn state
	current_turn_index = 0
	current_actor = null
	selected_action = ""
	selected_target = null
	menu_selection = 0
	in_skills_menu = false
	skill_selection = 0  # Reset skill menu selection
	enemy_attack_count = 0  # Reset enemy attack pattern
	
	# Reset UI
	if turn_label:
		turn_label.text = ""
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
	
	print("RESET→ Complete, starting new combat")
	change_state(State.BEGIN_TURN)

func end_turn():
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	change_state(State.BEGIN_TURN)

# Helper functions
func is_player(actor: Node) -> bool:
	return actor.name.begins_with("Player")

func get_enemy() -> Node:
	for actor in turn_order:
		if actor.name.begins_with("Enemy") and not actor.get("is_defeated"):
			return actor
	return null

func get_random_alive_player() -> Node:
	var alive_players = []
	for actor in turn_order:
		if is_player(actor) and not actor.get("is_defeated"):
			alive_players.append(actor)
	
	if alive_players.size() > 0:
		return alive_players[randi() % alive_players.size()]
	return null

func get_enemy_turn_count() -> int:
	# Count how many times enemy has acted (for deterministic pattern)
	# More accurate: count actual enemy turns that have occurred
	var enemy_turns = 0
	for i in range(current_turn_index):
		var actor_index = i % turn_order.size()
		if turn_order[actor_index].name.begins_with("Enemy"):
			enemy_turns += 1
	return enemy_turns

func toggle_music():
	music_enabled = !music_enabled
	if music_enabled:
		bgm_player.play()
		print("🎵 Music ON")
	else:
		bgm_player.stop()
		print("🔇 Music OFF")

func toggle_pause():
	if pause_overlay:
		if pause_overlay.visible:
			pause_overlay.hide_pause()
			print("PAUSE→ Game resumed")
		else:
			pause_overlay.show_pause()
			print("PAUSE→ Game paused")
	else:
		print("ERROR→ PauseOverlay not found")

# Turn order provider management
func set_turn_order_provider(provider: TurnOrderProvider) -> void:
	turn_order_provider = provider
	_refresh_turn_order()
	print("STATE→ Turn order provider changed to: ", provider.get_script().get_global_name())

func _refresh_turn_order() -> void:
	if turn_order_provider:
		var all_actors = [
			get_node("/root/BattleScene/Player1"),
			get_node("/root/BattleScene/Player2"), 
			get_node("/root/BattleScene/Enemy")
		]
		turn_order = turn_order_provider.get_round_order(all_actors)
		var actor_names = []
		for actor in turn_order:
			actor_names.append(actor.name)
		print("STATE→ Turn order refreshed: ", actor_names)

# Safe audio helper function - won't crash if AudioManager not available
func _safe_audio_call(method_name: String) -> void:
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if sfx_player:
		match method_name:
			"play_ui_move":
				sfx_player.stream = preload("res://assets/sfx/menu.wav")
				sfx_player.play()
			"play_ui_confirm":
				sfx_player.stream = preload("res://assets/sfx/menu.wav")
				sfx_player.play()
			_:
				print("[TurnManager] Unknown audio method: " + method_name)
	else:
		print("[TurnManager] SFXPlayer not found")
