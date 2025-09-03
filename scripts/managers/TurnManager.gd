extends Node

const TurnOrderProvider = preload("res://scripts/core/TurnOrderProvider.gd")

# STANDARDIZED CHARACTER ATTACK SYSTEM
# 
# All player characters should implement these methods for scalable combat:
# 
# REQUIRED METHODS:
# - start_attack_windup() -> await: Play windup animation, prepare for QTE
# - finish_attack_sequence(qte_result: String, target) -> await: Handle post-QTE animation and visual effects
# 
# SYSTEM FLOW:
# 1. TurnManager calls start_attack_windup() on character
# 2. TurnManager runs QTE
# 3. TurnManager calls finish_attack_sequence(result, target) on character
# 4. TurnManager handles all damage calculation, sound effects, and mechanical results
# 
# CHARACTER RESPONSIBILITIES:
# - Visual animations and effects only
# - No damage calculation or sound effects (TurnManager handles these)
# - Character-specific visual feedback (muzzle flash, sword trails, etc.)
# 
# TURNMANAGER RESPONSIBILITIES:  
# - All damage calculation based on QTE results
# - All sound effect playback (character-specific sounds supported)
# - All mechanical effects (resolve, buffs, etc.)
# - Consistent combat flow across all characters

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
	RESET_COMBAT,
	MAP_EXPLORATION,
	SHOP,
	UPGRADE
}

var current_state: State = State.BEGIN_TURN
var selection_description: Label

var turn_order = []
var current_turn_index: int = 0
var current_actor: Node = null
var selected_action: String = ""
var selected_target: Node = null
var item_used_this_turn: bool = false
var enemy_attack_count: int = 0
const GAME_OVER_THEME = "res://assets/music/closer.wav"

# UI References - match your exact paths
@onready var turn_label := get_node("../UILayer/TurnLabel")
@onready var action_menu := get_node_or_null("/root/BattleScene/UILayer/ActionMenu")
@onready var attack_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/AttackButton")
@onready var skills_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/SkillsButton")
@onready var item_button := get_node_or_null("/root/BattleScene/UILayer/ActionMenu/ItemButton")
@onready var skills_menu := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu")
@onready var items_menu := get_node_or_null("/root/BattleScene/UILayer/ItemsMenu")
@onready var skills_display := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu/SkillsDisplay")
@onready var bigshot_button := get_node_or_null("/root/BattleScene/UILayer/SkillsMenu/BigShotButton")
@onready var hp_potion_button := get_node_or_null("/root/BattleScene/UILayer/ItemsMenu/HPPotionButton")
@onready var resolve_potion_button := get_node_or_null("/root/BattleScene/UILayer/ItemsMenu/ResolvePotionButton")
@onready var bgm_player := get_node("../BGMPlayer")
@onready var result_overlay := get_node_or_null("/root/BattleScene/UILayer/ResultOverlay")
@onready var victory_overlay := get_node_or_null("/root/BattleScene/UILayer/VictoryOverlay")
@onready var pause_overlay := get_node_or_null("/root/BattleScene/UILayer/PauseOverlay")
@onready var coin_label := get_node_or_null("/root/BattleScene/UILayer/CoinDisplay/CoinLabel")

# Attack announcement UI
var attack_announcement_label: Label

# Menu state
var menu_selection: int = 0
var in_skills_menu: bool = false
var in_items_menu: bool = false
var skill_selection: int = 0  # For cycling through skills
var item_selection: int = 0  # For cycling through items

# Inventory now managed by ProgressManager (shared party inventory)

# Skill resolve costs - expandable for other skills
var skill_resolve_costs: Dictionary = {
	# Player1 skills
	"2x_cut": 1,
	"moonfall_slash": 3,
	"spirit_wave": 2,
	"uppercut": 1,
	# Player2 skills
	"big_shot": 2,
	"scatter_shot": 1,
	"focus": 2,  # Doubles damage, significant buff
	"grenade": 3,
	"bullet_rain": 3
}
var music_enabled: bool = true

# Input blocking to prevent QTE carryover
var input_blocked: bool = false

# Turn order provider system
var turn_order_provider: TurnOrderProvider

# Usage examples for switching providers:
# set_turn_order_provider(TurnOrderProvider.FixedOrderProvider.new())       # P1→P2→Enemy (default)
# set_turn_order_provider(TurnOrderProvider.InitiativeOrderProvider.new())  # Speed-based (stub)
# set_turn_order_provider(TurnOrderProvider.ScriptedOrderProvider.new())    # Event-driven (stub)

func _ready():
	AudioServer.set_bus_volume_db(0, -6.0)  # Force Master bus loud
	print("STATE→ INITIALIZING TurnManager")
	
	# Initialize selection_description reference safely
	selection_description = get_node_or_null("../UILayer/QTEContainer/SelectionDescriptionLabel")
	
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
	
	# Setup attack announcement UI
	_setup_attack_announcement_ui()
	
	# Initialize HP displays dynamically based on actual character HP
	_initialize_hp_displays()
	
	# Initialize Resolve system
	ResolveManager.reset_all_resolve()
	ProgressManager.apply_battle_buffs()  # Apply buffs after resolve reset
	
	# Initialize coin display and connect to updates
	update_coin_display()
	ProgressManager.coins_changed.connect(_on_coins_changed)
	
	# Start the state machine
	change_state(State.BEGIN_TURN)
	
	# Connect description updates
	if attack_button and selection_description:
		attack_button.focus_entered.connect(func(): selection_description.show_description("attack"))
	if skills_button and selection_description:
		skills_button.focus_entered.connect(func(): selection_description.hide_description())
	if bigshot_button and selection_description:
		bigshot_button.focus_entered.connect(func(): selection_description.show_description("big_shot"))
	if hp_potion_button and selection_description:
		hp_potion_button.focus_entered.connect(func(): selection_description.show_description("hp_potion"))
	# Item button if added later

func _on_menu_closed():
	if selection_description:
		selection_description.hide_description()

func show_action_menu(show: bool):
	if action_menu:
		action_menu.visible = show
		if not show:
			_on_menu_closed()

func _input(event):
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	
	# Pause toggle (works during any state except overlays)
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
		if (result_overlay and result_overlay.visible) or (victory_overlay and victory_overlay.visible):
			return  # Don't allow pause during overlays
		toggle_pause()
		return
	
	# Skip input if any overlay is showing
	if (result_overlay and result_overlay.visible) or (victory_overlay and victory_overlay.visible) or (pause_overlay and pause_overlay.visible):
		return
	
	# Block input during transition periods to prevent QTE carryover
	if input_blocked:
		print("INPUT→ Blocked during transition")
		return
	
	# Music toggle
	if event.keycode == KEY_M:
		toggle_music()
		return
	
	# DEBUG: Resolve testing (Q/A = Player1, E/D = Player2)
	if event.keycode == KEY_Q:
		ResolveManager.debug_increment_resolve("Player1")
		return
	if event.keycode == KEY_A:
		ResolveManager.debug_decrement_resolve("Player1") 
		return
	if event.keycode == KEY_E:
		ResolveManager.debug_increment_resolve("Player2")
		return
	if event.keycode == KEY_D:
		ResolveManager.debug_decrement_resolve("Player2")
		return
	
	# DEBUG: Quick enemy kill for testing (F key)
	if event.keycode == KEY_F:
		var enemy = get_enemy()
		if enemy and enemy.has_method("take_damage"):
			var damage_needed = enemy.hp - 1
			if damage_needed > 0:
				print("DEBUG→ Damaging enemy to 1 HP (", damage_needed, " damage)")
				enemy.take_damage(damage_needed)
			else:
				print("DEBUG→ Enemy already at 1 HP or less")
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
	elif in_items_menu:
		handle_items_menu_input(event)
	else:
		handle_action_menu_input(event)

func handle_action_menu_input(event):
	if event.is_action_pressed("move up"):
		menu_selection = max(0, menu_selection - 1)
		update_menu_highlight()
		_safe_audio_call("play_ui_move")
		print("MENU→ Selection: " + str(menu_selection))
		
	elif event.is_action_pressed("move down"):
		menu_selection = min(2, menu_selection + 1)  # Attack=0, Skills=1, Items=2
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
		elif menu_selection == 2:
			print("MENU→ Opening Items submenu")
			open_items_menu()
			
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
		
		# Check resolve cost before proceeding
		var current_player_name = current_actor.name
		if not can_afford_skill(current_player_name, selected_action):
			var cost = get_skill_resolve_cost(selected_action)
			var current_resolve = ResolveManager.get_resolve(current_player_name)
			print("MENU→ " + current_player_name + " cannot afford " + selected_action + " (cost: " + str(cost) + ", have: " + str(current_resolve) + ")")
			_safe_audio_call("play_ui_error")  # Error sound
			return
		
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
	_safe_audio_call("play_ui_confirm")
	in_skills_menu = true
	skill_selection = 0
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = true
	
	update_skills_menu_display()

func update_skills_menu_display():
	# Get current actor's abilities
	var abilities = current_actor.get_ability_list() if current_actor.has_method("get_ability_list") else []
	
	if abilities.size() == 0:
		# Fallback - hide display and button
		if skills_display:
			skills_display.visible = false
		if bigshot_button:
			bigshot_button.visible = false
		return
	
	# Clear existing text and setup for list display
	var skills_text = ""
	var current_player_name = current_actor.name
	
	for i in range(abilities.size()):
		var ability = abilities[i]
		var display_name = current_actor.get_ability_display_name(ability) if current_actor.has_method("get_ability_display_name") else ability
		var cost = get_skill_resolve_cost(ability)
		var can_afford = can_afford_skill(current_player_name, ability)
		
		# Build display text with resolve cost
		var skill_display = display_name
		if cost > 0:
			skill_display += " (" + str(cost) + ")"
		
		# Black out unaffordable skills using BBCode
		if not can_afford:
			skill_display = "[color=black]" + skill_display + "[/color]"
		
		# Add selection indicator for current skill
		if i == skill_selection:
			skills_text += "→ " + skill_display + " ←\n"
		else:
			skills_text += "  " + skill_display + "\n"
	
	# Display all skills in the RichTextLabel with BBCode support
	if skills_display:
		skills_display.visible = true
		skills_display.bbcode_enabled = true  # Ensure BBCode is enabled
		skills_display.text = skills_text.strip_edges()
	if bigshot_button:
		bigshot_button.visible = false
	
	# Update description for selected skill
	if selection_description and not is_instance_valid(selection_description):
		selection_description = get_node_or_null("../UILayer/QTEContainer/SelectionDescriptionLabel")
	
	if selection_description and is_instance_valid(selection_description):
		if abilities.size() > skill_selection:
			var selected_ability = abilities[skill_selection]
			selection_description.show_description(selected_ability)
		else:
			selection_description.hide_description()

func close_skills_menu():
	in_skills_menu = false
	if skills_menu:
		skills_menu.visible = false
	# Hide skills display and button
	if skills_display:
		skills_display.visible = false
	if bigshot_button:
		bigshot_button.visible = false
	# Restore action menu and update highlighting
	if action_menu:
		action_menu.visible = true
	update_menu_highlight()

func handle_items_menu_input(event):
	if event.is_action_pressed("move up"):  # W moves up in items menu
		item_selection = max(0, item_selection - 1)
		update_items_menu_display()
		_safe_audio_call("play_ui_move")
		print("MENU→ Item selection: " + str(item_selection))
		
	elif event.is_action_pressed("move down"):  # S moves down in items menu
		item_selection = min(1, item_selection + 1)  # 0=HP Potion, 1=Resolve Potion
		update_items_menu_display()
		_safe_audio_call("play_ui_move")
		print("MENU→ Item selection: " + str(item_selection))
		
	elif event.is_action_pressed("confirm attack"):  # Z confirms
		_safe_audio_call("play_ui_confirm")
		
		var current_player_name = current_actor.name
		var potion_type = ""
		var potion_count = 0
		
		if item_selection == 0:  # HP Potion
			potion_type = "hp_potion"
		elif item_selection == 1:  # Resolve Potion
			potion_type = "resolve_potion"
		
		potion_count = get_player_potion_count(current_player_name, potion_type)
		
		if potion_count <= 0:
			print("MENU→ " + current_player_name + " has no " + potion_type + " left!")
			_safe_audio_call("play_ui_error")
			return
		
		if item_used_this_turn:
			print("MENU→ " + current_player_name + " already used an item this turn!")
			_safe_audio_call("play_ui_error")
			return
		
		# Use item immediately without QTE
		await use_item_immediately(potion_type)
		
		# End turn after item usage (as requested)
		close_items_menu()
		end_turn()
		return
		
	elif event.is_action_pressed("cancel dodge"):  # C backs out
		print("MENU→ Backing out of Items menu")
		close_items_menu()

func open_items_menu():
	_safe_audio_call("play_ui_confirm")  # Play sound when opening items menu
	in_items_menu = true
	item_selection = 0  # Reset to first item
	if action_menu:
		action_menu.visible = false
	if items_menu:
		items_menu.visible = true
	
	update_items_menu_display()

func update_items_menu_display():
	var current_player_name = current_actor.name
	var hp_count = get_player_potion_count(current_player_name, "hp_potion")
	var resolve_count = get_player_potion_count(current_player_name, "resolve_potion")
	
	var hp_text = "HP Potion " + str(hp_count)
	var resolve_text = "Resolve Potion " + str(resolve_count)
	
	# Add usage indicator if item was already used this turn
	if item_used_this_turn:
		hp_text += " (USED)"
		resolve_text += " (USED)"
	
	# Update HP Potion button
	if hp_potion_button:
		hp_potion_button.visible = true
		hp_potion_button.text = hp_text
		hp_potion_button.disabled = (hp_count <= 0 or item_used_this_turn)
		
		# Highlight selected item
		if item_selection == 0:
			hp_potion_button.grab_focus()
	
	# Update Resolve Potion button
	if resolve_potion_button:
		resolve_potion_button.visible = true
		resolve_potion_button.text = resolve_text
		resolve_potion_button.disabled = (resolve_count <= 0 or item_used_this_turn)
		
		# Highlight selected item
		if item_selection == 1:
			resolve_potion_button.grab_focus()
	
	# Show selection description
	if selection_description:
		if item_selection == 0:
			selection_description.show_description("hp_potion")
		elif item_selection == 1:
			selection_description.show_description("resolve_potion")

func close_items_menu():
	in_items_menu = false
	if items_menu:
		items_menu.visible = false
	if hp_potion_button:
		hp_potion_button.visible = false
	if resolve_potion_button:
		resolve_potion_button.visible = false
	if selection_description:
		selection_description.hide_description()
	if action_menu:
		action_menu.visible = true
	update_menu_highlight()

# Inventory helper functions - now use shared ProgressManager inventory
func get_player_potion_count(player_name: String, potion_type: String) -> int:
	# All players share the same party inventory
	return ProgressManager.get_party_item_count(potion_type)

func use_player_potion(player_name: String, potion_type: String) -> bool:
	# Use from shared party inventory
	return ProgressManager.use_party_item(potion_type)

# New function for immediate item usage (no QTE, with animation)
func use_item_immediately(item_name: String):
	print("ITEM→ Using " + item_name + " immediately")
	
	# Play drink animation using AnimationBridge system (like grenade/bullet_rain)
	if current_actor.name == "Player2":
		print("ITEM→ Playing drink animation for Player2 via AnimationBridge")
		
		# Use AnimationBridge system - let animation use its natural position
		var animation_instance = AnimationBridge.spawn_ability_animation("drink", Vector2.ZERO, current_actor)
		if animation_instance:
			# Play the drink animation
			AnimationBridge.play_windup_animation("drink")
			await AnimationBridge.animation_ready_for_qte
			
			# For drink, we don't need QTE result, just play success animation
			AnimationBridge.play_result_animation("drink", "success")
			await AnimationBridge.animation_sequence_complete
			print("ITEM→ Drink animation completed via AnimationBridge")
		else:
			print("ITEM→ Failed to spawn drink animation")
			await get_tree().create_timer(0.5).timeout
	else:
		print("ITEM→ No drink animation available for " + current_actor.name + " (only Player2 has drink animation)")
		# Brief delay for feedback
		await get_tree().create_timer(0.5).timeout
	
	# Handle specific items
	match item_name:
		"hp_potion":
			var current_player_name = current_actor.name
			var used_successfully = use_player_potion(current_player_name, "hp_potion")
			
			if used_successfully:
				var heal_amount = 50
				var old_hp = current_actor.hp
				current_actor.hp = min(current_actor.hp + heal_amount, current_actor.hp_max)
				var actual_heal = current_actor.hp - old_hp
				
				# Update HP bar UI
				if current_actor.name == "Player1":
					CombatUI.update_hp_bar("Player1", current_actor.hp, current_actor.hp_max)
				elif current_actor.name == "Player2":
					CombatUI.update_hp_bar("Player2", current_actor.hp, current_actor.hp_max)
				
				# Show green healing popup
				var popup_scene = load("res://scenes/DamagePopup.tscn")
				if popup_scene:
					var popup = popup_scene.instantiate()
					current_actor.add_child(popup)
					popup.position = Vector2(90, -50)
					popup.show_damage(actual_heal, "heal")
				
				print("HEAL→ " + current_actor.name + " healed " + str(actual_heal) + " HP (now " + str(current_actor.hp) + "/" + str(current_actor.hp_max) + ")")
				
				# Mark item as used this turn
				item_used_this_turn = true
			else:
				print("ERROR→ " + current_player_name + " tried to use HP Potion but had none!")
		"resolve_potion":
			var current_player_name = current_actor.name
			var used_successfully = use_player_potion(current_player_name, "resolve_potion")
			
			if used_successfully:
				var resolve_amount = 3
				var old_resolve = ResolveManager.get_resolve(current_player_name)
				var max_resolve = 6  # Maximum resolve is 6 as shown in UI
				var new_resolve = min(old_resolve + resolve_amount, max_resolve)
				var actual_gain = new_resolve - old_resolve
				
				ResolveManager.set_resolve(current_player_name, new_resolve)
				
				# Show blue resolve popup
				var popup_scene = load("res://scenes/DamagePopup.tscn")
				if popup_scene:
					var popup = popup_scene.instantiate()
					current_actor.add_child(popup)
					popup.position = Vector2(90, -50)
					popup.show_damage(actual_gain, "resolve")  # Assuming DamagePopup supports resolve type
				
				print("RESOLVE→ " + current_actor.name + " gained " + str(actual_gain) + " Resolve (now " + str(new_resolve) + "/" + str(max_resolve) + ")")
				
				# Mark item as used this turn
				item_used_this_turn = true
			else:
				print("ERROR→ " + current_player_name + " tried to use Resolve Potion but had none!")
		_:
			print("WARNING→ Unknown item: " + item_name)

# Skill resolve cost helper functions
func get_skill_resolve_cost(skill_name: String) -> int:
	if skill_name in skill_resolve_costs:
		return skill_resolve_costs[skill_name]
	return 0  # No cost for unknown skills

func can_afford_skill(player_name: String, skill_name: String) -> bool:
	var cost = get_skill_resolve_cost(skill_name)
	var current_resolve = ResolveManager.get_resolve(player_name)
	return current_resolve >= cost

func spend_skill_resolve(player_name: String, skill_name: String) -> bool:
	if can_afford_skill(player_name, skill_name):
		var cost = get_skill_resolve_cost(skill_name)
		var current_resolve = ResolveManager.get_resolve(player_name)
		ResolveManager.set_resolve(player_name, current_resolve - cost)
		print("RESOLVE→ " + player_name + " spent " + str(cost) + " resolve for " + skill_name)
		return true
	return false

func update_menu_highlight():
	# Check node validity before using
	if selection_description and not is_instance_valid(selection_description):
		selection_description = get_node_or_null("../UILayer/QTEContainer/SelectionDescriptionLabel")
	
	# Simple highlighting using button focus
	if attack_button and skills_button and item_button:
		if menu_selection == 0:
			attack_button.grab_focus()
			if selection_description and is_instance_valid(selection_description):
				selection_description.show_description("attack")
		elif menu_selection == 1:
			skills_button.grab_focus()
			if selection_description and is_instance_valid(selection_description):
				selection_description.hide_description()
		elif menu_selection == 2:
			item_button.grab_focus()
			if selection_description and is_instance_valid(selection_description):
				selection_description.hide_description()

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
	in_items_menu = false
	skill_selection = 0
	item_selection = 0
	item_used_this_turn = false  # Reset item usage for new turn
	
	# Ensure all submenus are hidden at turn start
	if skills_menu:
		skills_menu.visible = false
	if items_menu:
		items_menu.visible = false
	if skills_display:
		skills_display.visible = false
	if bigshot_button:
		bigshot_button.visible = false
	if hp_potion_button:
		hp_potion_button.visible = false
	
	# Hide any lingering descriptions with node validation
	if selection_description and is_instance_valid(selection_description):
		selection_description.hide_description()
	elif not selection_description or not is_instance_valid(selection_description):
		selection_description = get_node_or_null("../UILayer/QTEContainer/SelectionDescriptionLabel")
	
	# Play turn ready sound for players only
	if is_player(current_actor):
		var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/turn_ready.wav")
			sfx_player.play()
			print("🎵 Playing turn ready sound for " + current_actor.name)
	
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
		
	# Determine enemy attack pattern (deterministic rotation) - 5 attacks total
	var attack_index = enemy_attack_count % 5
	print("DEBUG→ Enemy attack count: " + str(enemy_attack_count))
	print("DEBUG→ Attack index: " + str(attack_index))
	enemy_attack_count += 1  # Increment for next time
	
	match attack_index:
		0:
			selected_action = "multishot"
			print("ENEMY→ Multishot (projectile deflect QTE)")
		1:
			selected_action = "mirror_strike"
			print("ENEMY→ Mirror Strike (copy-cat QTE)")
		2:
			selected_action = "arc_slash"
			print("ENEMY→ Arc Slash (single-tap QTE)")
		3:
			selected_action = "lightning_surge" 
			print("ENEMY→ Lightning Surge (multi-tap QTE)")
		4:
			selected_action = "phase_slam"
			print("ENEMY→ Phase Slam (hold QTE)")
			# Play Phase Slam wind-up sound early
			var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/phaseslam1.wav")
				sfx_player.play()
				print("🎵 Playing Phase Slam wind-up sound (phaseslam1.wav)")
	
	# Show attack announcement (2 second display)
	await show_attack_announcement(selected_action)
	
	change_state(State.QTE_ACTIVE)

func start_qte():
	print("STATE→ QTE_ACTIVE")
	
	# Hide all menus during QTE to prevent confusion
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
	
	var qte_result: String
	
	if is_player(current_actor):
		# Small delay to prevent menu input carryover
		await get_tree().create_timer(1.0).timeout
		
		# Player offense - STANDARDIZED SYSTEM for all characters
		if selected_action == "attack":
			# Use AnimationBridge system for Player2, old system for others
			if current_actor.name == "Player2":
				print("🔫 Using AnimationBridge system for Player2 basic attack")
				# Step 1: Spawn animation and play windup
				var animation_instance = AnimationBridge.spawn_ability_animation("basic_attack", Vector2.ZERO, current_actor)
				if animation_instance:
					AnimationBridge.play_windup_animation("basic_attack")
					await AnimationBridge.animation_ready_for_qte
					
					# Step 2: QTE during windup
					if selection_description:
						selection_description.hide_description()
					qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z!", current_actor)
					
					# Play sound effect immediately after QTE success
					_play_attack_sound_effect(qte_result, current_actor)
					
					# Step 3: Play result animation based on QTE result
					AnimationBridge.play_result_animation("basic_attack", qte_result)
					await AnimationBridge.animation_sequence_complete
					print("🔫 Player2 AnimationBridge attack sequence complete")
				else:
					print("❌ Failed to spawn Player2 basic attack animation")
					qte_result = "fail"
			# Universal pattern for other players: windup → QTE → finish sequence
			elif current_actor.has_method("start_attack_windup") and current_actor.has_method("finish_attack_sequence"):
				# Step 1: Play windup animation
				await current_actor.start_attack_windup()
				# Step 2: QTE during windup
				if selection_description:
					selection_description.hide_description()
				qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z!", current_actor)
				
				# Play sound effect immediately after QTE success
				_play_attack_sound_effect(qte_result, current_actor)
				
				# Step 3: Finish attack animation based on result
				await current_actor.finish_attack_sequence(qte_result, selected_target)
			else:
				# Fallback for characters without standardized system
				print("⚠️ Character " + current_actor.name + " using legacy attack system")
				if selection_description:
					selection_description.hide_description()
				qte_result = await QTEManager.start_qte("confirm attack", 800, "Press Z!", current_actor)
				
				# Play sound effect immediately after QTE success
				_play_attack_sound_effect(qte_result, current_actor)
				
				if current_actor.has_method("attack"):
					await current_actor.attack(selected_target)
		else:
			# Handle abilities (not basic attacks)
			# Note: Items are now handled immediately in the menu, not here
			# Handle self-buff abilities that don't need a target
			if selected_action == "focus":
				await current_actor.execute_ability(selected_action, null)
				qte_result = "handled"  # Flag that player handled it
			# All other abilities use the player's ability system
			elif current_actor.has_method("execute_ability") and selected_target:
				# Spend resolve for the skill
				var current_player_name = current_actor.name
				spend_skill_resolve(current_player_name, selected_action)
				
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
		
		# Play incoming attack warning sound (skip for Phase Slam - it has its own sound)
		if selected_action != "phase_slam":
			var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/incoming.wav")
				sfx_player.play()
				print("🚨 Playing incoming attack warning")
		else:
			print("🚨 Skipping incoming.wav - Phase Slam has its own sound")
		
		# Wait 1 second (zoom completes + dramatic pause)
		await get_tree().create_timer(1.0).timeout
		
		# Enemy attack QTE (X button for defense)
		if selection_description:
			selection_description.hide_description()
		match selected_action:
			"multishot":
				qte_result = await QTEManager.start_qte("multishot", 5000, "PARRY THE INCOMING BOXES!", selected_target)
			"arc_slash":
				qte_result = await QTEManager.start_qte("parry", 700, "Press X to parry!", selected_target)
			"lightning_surge":
				qte_result = await QTEManager.start_qte("parry", 500, "Press X rapidly!", selected_target)
			"phase_slam":
				qte_result = await QTEManager.start_qte("parry", 900, "Hold X, release on cue!", selected_target)
			"mirror_strike":
				qte_result = await QTEManager.start_qte("mirror_strike", 7000, "REPEAT THE SEQUENCE!", selected_target)
	
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
			# Only basic attack uses TurnManager damage calculation - binary result
			match qte_result:
				"crit", "normal": 
					damage = 8  # Success = consistent damage
					# Award resolve for successful attack
					ResolveManager.set_resolve(current_actor.name, ResolveManager.get_resolve(current_actor.name) + 1)
				"fail": damage = 0            # Fail = no damage
			var target_name = "null target"
			if selected_target:
				target_name = selected_target.name
			print("DMG→ Player deals " + str(damage) + " to " + target_name)
			
			# Sound effects now play immediately after QTE success (moved up for better timing)
			
			# Apply damage and hit effects
			if damage > 0 and selected_target and selected_target.has_method("take_damage"):
				selected_target.take_damage(damage)
				# Play hit effects for successful attacks
				VFXManager.play_hit_effects(selected_target)
		else:
			print("WARNING→ Unhandled player action: " + selected_action)
			
	else:
		# Enemy action damage (mitigated by parry)
		var base_damage = 0
		match selected_action:
			"arc_slash": base_damage = 25  # Light attack - 3-tier parry system
			"lightning_surge": base_damage = 120  # 6+6
			"phase_slam": base_damage = 70  # Heavy attack - timing-based parry
			"mirror_strike": base_damage = 30  # Sequence defense - binary (perfect/fail)
			
		# Apply battle progression damage scaling
		var damage_multiplier = ProgressManager.get_enemy_damage_multiplier()
		base_damage = int(base_damage * damage_multiplier)
		var battle_number = ProgressManager.get_current_battle_number()
		print("ENEMY→ Battle ", battle_number, " damage: ", base_damage, " (", int(damage_multiplier * 100), "% of base)")
			
		# Show enemy attack animation (sound handled by QTE Manager)
		if current_actor.has_method("attack_animation"):
			current_actor.attack_animation(selected_target, selected_action, false)
			
		# Reduced delay for faster turn switching
		await get_tree().create_timer(0.2).timeout
			
		# Apply parry mitigation with graduated timing for Lightning Surge
		var mitigation = 0.0
		if selected_action == "mirror_strike":
			# Mirror Strike: perfect = 0 damage, fail = full damage
			if qte_result == "perfect":
				damage = 0
				print("DMG→ Mirror Strike: Perfect sequence! No damage taken.")
			else:
				damage = base_damage
				print("DMG→ Mirror Strike: Failed sequence! " + str(damage) + " damage to " + selected_target.name)
			
			# Award resolve for perfect mirror strike sequence
			if damage == 0:
				ResolveManager.set_resolve(selected_target.name, ResolveManager.get_resolve(selected_target.name) + 1)
				print("RESOLVE→ " + selected_target.name + " gains +1 resolve for perfect mirror strike sequence!")
			
			# Apply mirror strike damage directly
			if damage > 0:
				print("DEBUG→ Applying " + str(damage) + " mirror strike damage to target: " + str(selected_target))
				if selected_target == null:
					print("ERROR→ selected_target is NULL!")
				elif not selected_target.has_method("take_damage"):
					print("ERROR→ selected_target missing take_damage method!")
				else:
					print("DEBUG→ Calling take_damage(" + str(damage) + ") on " + selected_target.name)
					selected_target.take_damage(damage)
			else:
				print("DEBUG→ No mirror strike damage to apply (perfect defense)")
			
		elif selected_action == "lightning_surge":
			# Per-strike damage calculation for Lightning Surge
			var failed_strikes = int(qte_result)  # QTE returns number of failed strikes as string
			damage = failed_strikes * 10  # 10 damage per failed strike
			print("DMG→ Lightning Surge: " + str(failed_strikes) + " strikes hit for " + str(damage) + " damage to " + selected_target.name)
			
			# Award resolve for perfect lightning surge defense
			if damage == 0:
				ResolveManager.set_resolve(selected_target.name, ResolveManager.get_resolve(selected_target.name) + 1)
				print("RESOLVE→ " + selected_target.name + " gains +1 resolve for perfect lightning surge defense!")
			
			# Apply lightning surge damage directly
			if damage > 0:
				print("DEBUG→ Applying " + str(damage) + " lightning damage to target: " + str(selected_target))
				if selected_target == null:
					print("ERROR→ selected_target is NULL!")
				elif not selected_target.has_method("take_damage"):
					print("ERROR→ selected_target missing take_damage method!")
				else:
					print("DEBUG→ Calling take_damage(" + str(damage) + ") on " + selected_target.name)
					selected_target.take_damage(damage)
			else:
				print("DEBUG→ No lightning damage to apply (perfect defense = " + str(damage) + " damage)")
			
			# Lightning surge damage handled directly above, skip normal damage calculation
		else:
			# 3-tier parry system for arc_slash, binary for others
			if selected_action == "arc_slash":
				match qte_result:
					"perfect": mitigation = 1.0   # 0% damage (perfect parry)
					"normal": mitigation = 0.4    # 40% damage reduction (late parry) 
					"fail": mitigation = 0.0      # 100% damage (missed parry)
			else:
				# Standard binary mitigation for other attacks
				match qte_result:
					"normal", "perfect": mitigation = 1.0   # 0% damage (successful parry)
					"fail": mitigation = 0.0     # 100% damage (failed parry)
			
			damage = int(base_damage * (1.0 - mitigation))
			print("DMG→ Enemy deals " + str(damage) + " to " + selected_target.name + " (base: " + str(base_damage) + ", " + qte_result + " parry = " + str(int(mitigation * 100)) + "% mitigated)")
			
			# Award resolve for perfect parries/defenses
			if selected_action == "arc_slash" and qte_result == "perfect" and damage == 0:
				ResolveManager.set_resolve(selected_target.name, ResolveManager.get_resolve(selected_target.name) + 1)
				print("RESOLVE→ " + selected_target.name + " gains +1 resolve for perfect arc_slash parry!")
			elif selected_action == "phase_slam" and (qte_result == "perfect" or qte_result == "normal") and damage == 0:
				ResolveManager.set_resolve(selected_target.name, ResolveManager.get_resolve(selected_target.name) + 1)
				print("RESOLVE→ " + selected_target.name + " gains +1 resolve for successful phase_slam defense!")
			
			# Play Phase Slam impact sound after QTE resolves
			if selected_action == "phase_slam":
				var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
				if sfx_player:
					sfx_player.stream = preload("res://assets/sfx/phaseslam2.wav")
					sfx_player.play()
					print("🎵 Playing Phase Slam impact sound (phaseslam2.wav)")
			
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
	
	# Block input and add delay to prevent QTE button mashing carryover
	input_blocked = true
	print("TURNMGR→ Blocking input for 0.3 seconds to prevent carryover")
	_clear_pending_inputs()
	await get_tree().create_timer(0.3).timeout
	_clear_pending_inputs()  # Clear again after delay
	input_blocked = false
	print("TURNMGR→ Input unblocked")
	
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
	
	# Award coins for victory
	ProgressManager.complete_battle()
	
	# Show victory overlay with map exploration
	show_victory_overlay()

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

func show_victory_overlay():
	print("TURNMGR→ Showing victory overlay")
	if victory_overlay and victory_overlay.has_method("show_victory"):
		victory_overlay.show_victory()
	else:
		print("ERROR→ VictoryOverlay not found or missing show_victory method")

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
	
	# Force HP bar updates with actual HP values
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	var player2 = get_node_or_null("/root/BattleScene/Player2")
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	
	if player1:
		CombatUI.update_hp_bar("Player1", player1.hp, player1.hp_max)
	if player2:
		CombatUI.update_hp_bar("Player2", player2.hp, player2.hp_max)
	if enemy:
		CombatUI.update_hp_bar("Enemy", enemy.hp, enemy.hp_max)
	
	# Reset Resolve system
	ResolveManager.reset_all_resolve()
	ProgressManager.apply_battle_buffs()  # Apply buffs after resolve reset
	
	# Reset turn state
	current_turn_index = 0
	current_actor = null
	selected_action = ""
	selected_target = null
	menu_selection = 0
	in_skills_menu = false
	in_items_menu = false
	skill_selection = 0  # Reset skill menu selection
	item_selection = 0  # Reset item menu selection
	item_used_this_turn = false  # Reset item usage flag
# NOTE: party_inventory managed by ProgressManager - persists across battles
	enemy_attack_count = 0  # Reset enemy attack pattern
	input_blocked = false  # Ensure input is not blocked on reset
	
	# Reset UI
	if turn_label:
		turn_label.text = ""
	if action_menu:
		action_menu.visible = false
	if skills_menu:
		skills_menu.visible = false
	
	print("RESET→ Complete, starting new combat")

# Initialize HP displays with actual character values (not hardcoded)
func _initialize_hp_displays():
	print("HP→ Initializing dynamic HP displays")
	
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	var player2 = get_node_or_null("/root/BattleScene/Player2")
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	
	# Update player HP labels with actual values
	if player1:
		CombatUI.update_hp_bar("Player1", player1.hp, player1.hp_max)
		print("HP→ Player1 initialized: ", player1.hp, "/", player1.hp_max)
	
	if player2:
		CombatUI.update_hp_bar("Player2", player2.hp, player2.hp_max)
		print("HP→ Player2 initialized: ", player2.hp, "/", player2.hp_max)
	
	if enemy:
		CombatUI.update_hp_bar("Enemy", enemy.hp, enemy.hp_max)
		print("HP→ Enemy initialized: ", enemy.hp, "/", enemy.hp_max)

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

# Clear any pending input events to prevent carryover
func _clear_pending_inputs() -> void:
	Input.flush_buffered_events()
	print("TURNMGR→ Cleared pending input events")

# Play attack sound effect based on QTE result and player type
func _play_attack_sound_effect(qte_result: String, actor: Node):
	var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
	if not sfx_player:
		return
		
	match qte_result:
		"crit":
			if actor.name == "Player2":
				sfx_player.stream = preload("res://assets/sfx/gun2.wav")  # Gun Girl crit
			else:
				sfx_player.stream = preload("res://assets/sfx/crit.wav")   # Sword Spirit crit
			sfx_player.play()
		"normal":
			if actor.name == "Player2":
				sfx_player.stream = preload("res://assets/sfx/gun1.wav")  # Gun Girl normal
			else:
				sfx_player.stream = preload("res://assets/sfx/attack.wav") # Sword Spirit normal
			sfx_player.play()
		"fail":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")  # Same miss sound for both
			sfx_player.play()

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

func _setup_attack_announcement_ui():
	# Create attack announcement label
	attack_announcement_label = Label.new()
	attack_announcement_label.name = "AttackAnnouncement"
	attack_announcement_label.visible = false
	
	# Position at center-top of screen
	attack_announcement_label.anchors_preset = Control.PRESET_CENTER_TOP
	attack_announcement_label.anchor_left = 0.5
	attack_announcement_label.anchor_right = 0.5
	attack_announcement_label.anchor_top = 0.0
	attack_announcement_label.offset_left = -150  # Half width to center the text
	attack_announcement_label.offset_right = 150   # Half width to center the text
	attack_announcement_label.offset_top = 50
	attack_announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style to match menu buttons (large, bold text)
	attack_announcement_label.add_theme_font_size_override("font_size", 32)
	attack_announcement_label.add_theme_color_override("font_color", Color.WHITE)
	attack_announcement_label.add_theme_color_override("font_outline_color", Color.BLACK)
	attack_announcement_label.add_theme_constant_override("outline_size", 3)
	
	# Add semi-transparent background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Dark semi-transparent
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.content_margin_bottom = 10
	style_box.content_margin_left = 20
	style_box.content_margin_right = 20
	style_box.content_margin_top = 10
	attack_announcement_label.add_theme_stylebox_override("normal", style_box)
	
	# Add to UILayer
	var ui_layer = get_node("/root/BattleScene/UILayer")
	if ui_layer:
		ui_layer.add_child(attack_announcement_label)
		print("UI→ Attack announcement label created")
	else:
		print("ERROR→ Could not find UILayer for attack announcement")

func show_attack_announcement(attack_name: String):
	if not attack_announcement_label:
		print("ERROR→ Attack announcement label not found")
		return
	
	# Map attack names to display text
	var display_name = ""
	match attack_name:
		"arc_slash": display_name = "ARC SLASH"
		"lightning_surge": display_name = "LIGHTNING SURGE"
		"phase_slam": display_name = "PHASE SLAM"
		"mirror_strike": display_name = "MIRROR STRIKE"
		"multishot": display_name = "MULTISHOT"
		_: display_name = attack_name.to_upper()
	
	# Show announcement
	attack_announcement_label.text = display_name
	attack_announcement_label.visible = true
	print("UI→ Showing attack announcement: ", display_name)
	
	# Auto-hide after 2 seconds
	await get_tree().create_timer(2.0).timeout
	attack_announcement_label.visible = false
	print("UI→ Attack announcement hidden")

# Update coin display
func update_coin_display():
	if coin_label:
		coin_label.text = str(ProgressManager.player_coins)
		print("UI→ Coin display updated: ", ProgressManager.player_coins)
	else:
		print("ERROR→ Coin label not found")

# Signal handler for coin changes
func _on_coins_changed(new_amount: int):
	update_coin_display()
