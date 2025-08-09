extends Node

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

# UI References - match your exact paths
@onready var turn_label := get_node("../UILayer/TurnLabel")
@onready var action_menu := get_node_or_null("/root/BattleScene/UILayer/ActionMenu")
@onready var attack_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/AttackButton")
@onready var skills_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/SkillsButton")
@onready var bgm_player := get_node("../BGMPlayer")

# Menu state
var menu_selection: int = 0
var music_enabled: bool = true

func _ready():
	print("STATE→ INITIALIZING TurnManager")
	
	# Set up turn order
	turn_order = [
		get_node("/root/BattleScene/Player1"),
		get_node("/root/BattleScene/Player2"), 
		get_node("/root/BattleScene/Enemy")
	]
	
	# Start the state machine
	change_state(State.BEGIN_TURN)

func _input(event):
	if not event is InputEventKey:
		return
	if not event.pressed:
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
	if event.is_action_pressed("move up"):
		menu_selection = max(0, menu_selection - 1)
		update_menu_highlight()
		print("MENU→ Selection: " + str(menu_selection))
		
	elif event.is_action_pressed("move down"):
		menu_selection = min(1, menu_selection + 1)  # Attack=0, Skills=1
		update_menu_highlight()
		print("MENU→ Selection: " + str(menu_selection))
		
	elif event.is_action_pressed("confirm attack"):  # Z confirms
		if menu_selection == 0:
			selected_action = "attack"
			selected_target = get_enemy()
			print("MENU→ Attack selected")
			change_state(State.QTE_ACTIVE)
		elif menu_selection == 1:
			selected_action = "skill"
			selected_target = get_enemy()
			print("MENU→ Skill selected")
			change_state(State.QTE_ACTIVE)
			
	elif event.is_action_pressed("cancel dodge"):  # C cancels
		print("MENU→ Cancel pressed (no effect at top level)")

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
	
	if action_menu:
		action_menu.visible = true
		
	update_menu_highlight()

func enemy_think():
	print("STATE→ ENEMY_THINK")
	
	# Hide any player menus
	if action_menu:
		action_menu.visible = false
		
	# Brief delay for enemy "thinking"
	await get_tree().create_timer(1.0).timeout
	
	# Enemy selects attack and target
	selected_target = get_random_alive_player()
	if selected_target == null:
		print("STATE→ No valid targets, ending turn")
		end_turn()
		return
		
	# Determine enemy attack pattern (deterministic rotation)
	var enemy_turn_count = get_enemy_turn_count()
	var attack_index = enemy_turn_count % 3
	
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
	
	# Small delay to prevent menu input carryover
	await get_tree().create_timer(1.0).timeout
	
	var qte_result: String
	
	if is_player(current_actor):
		# Player offense QTE (Z button)
		if selected_action == "attack":
			qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z to attack!", current_actor)
		elif selected_action == "skill":
			qte_result = await QTEManager.start_qte("confirm attack", 1000, "Hold Z and release!", current_actor)
	else:
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
		if selected_action == "attack":
			match qte_result:
				"crit": damage = 10
				"normal": damage = 6
				"fail": damage = 0
		elif selected_action == "skill":
			match qte_result:
				"crit": damage = 16
				"normal": damage = 10
				"fail": damage = 0
				
		print("DMG→ Player deals " + str(damage) + " to " + selected_target.name)
		if damage > 0 and selected_target.has_method("take_damage"):
			selected_target.take_damage(damage)
			
	else:
		# Enemy action damage (mitigated by parry)
		var base_damage = 0
		match selected_action:
			"arc_slash": base_damage = 10
			"lightning_surge": base_damage = 12  # 6+6
			"phase_slam": base_damage = 18
			
		# Show enemy attack animation
		if current_actor.has_method("attack_animation"):
			current_actor.attack_animation(selected_target)
			
		# ADD THIS LINE - delay to see the animation
		await get_tree().create_timer(0.8).timeout
			
		# Apply parry mitigation
		var mitigation = 0.0
		match qte_result:
			"normal": mitigation = 0.0   # 0% damage (successful parry)
			"fail": mitigation = 1.0     # 100% damage (failed parry)
			
		damage = int(base_damage * mitigation)
		print("DMG→ Enemy deals " + str(damage) + " to " + selected_target.name + " (base: " + str(base_damage) + ", mitigated: " + str(int(mitigation * 100)) + "%)")
		
		if damage > 0 and selected_target.has_method("take_damage"):
			selected_target.take_damage(damage)
			
		# Hide enemy attack animation after damage
		if current_actor.has_method("end_attack_animation"):
			current_actor.end_attack_animation()
	
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
		
	# Wait for player input or auto-reset
	await get_tree().create_timer(2.0).timeout
	change_state(State.RESET_COMBAT)

func game_over():
	print("STATE→ GAME_OVER") 
	if turn_label:
		turn_label.text = "DEFEAT..."
		
	# Hide menus
	if action_menu:
		action_menu.visible = false
		
	# Wait for player input or auto-reset
	await get_tree().create_timer(2.0).timeout
	change_state(State.RESET_COMBAT)

func reset_combat():
	print("RESET→ Resetting combat to initial state")
	
	# Reset all actors
	for actor in turn_order:
		if actor.has_method("reset_for_new_combat"):
			actor.reset_for_new_combat()
		else:
			# Default reset
			if actor.has_method("set"):
				actor.hp = actor.hp_max
				actor.is_defeated = false
	
	# Reset turn state
	current_turn_index = 0
	current_actor = null
	selected_action = ""
	selected_target = null
	menu_selection = 0
	
	# Reset UI
	if turn_label:
		turn_label.text = ""
	if action_menu:
		action_menu.visible = false
	
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
	# This is a simple implementation - you might want to track this more robustly
	return current_turn_index / turn_order.size()

func toggle_music():
	music_enabled = !music_enabled
	if music_enabled:
		bgm_player.play()
		print("🎵 Music ON")
	else:
		bgm_player.stop()
		print("🔇 Music OFF")
