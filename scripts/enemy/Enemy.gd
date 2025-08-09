extends Node2D  # keep whatever your scene uses

var hp_max: int = 150
var hp: int = hp_max
var is_defeated: bool = false
var rng := RandomNumberGenerator.new()
var turn_order = []
var current_turn_index = 0
var game_over = false
var current_actor: Node = null
var waiting_for_input = false
var qte_active = false
var selected_ability = ""

@onready var turn_label := get_node("../UILayer/TurnLabel")
@onready var attack_button := get_node("/root/BattleScene/UILayer/ActionMenu/AttackButton")
@onready var skills_button := get_node("/root/BattleScene/UILayer/ActionMenu/SkillsButton")
@onready var action_menu := get_node("/root/BattleScene/UILayer/ActionMenu")
# @onready var skills_menu := get_node("/root/BattleScene/UILayer/SkillsMenu")
# @onready var skills_list := get_node("/root/BattleScene/UILayer/SkillsMenu/SkillsList")
@onready var bgm_player := get_node("../BGMPlayer")
@onready var sfx_player := get_node("../SFXPlayer")
var music_enabled = true

func attack(target: Node) -> void:
	if is_defeated:
		return

	var dmg := randi_range(6, 12)
	print(name, "attacks ->", target.name, "for", dmg)

	if target and target.has_method("take_damage"):
		target.take_damage(dmg)



func _unhandled_input(event):
	if event.is_action_pressed("confirm attack") and waiting_for_input and not qte_active:
		if attack_button.has_focus():
			on_attack_pressed()
		# MVP lock: skills disabled for now
		#elif skills_button.has_focus():
		#	on_skills_pressed()

	# MVP lock: no SkillsMenu, so no cancel handling for it
	# if event.is_action_pressed("ui_cancel") and skills_menu and skills_menu.visible:
	#	hide_skills_menu()

	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		toggle_music()

func toggle_music():
	music_enabled = !music_enabled
	if music_enabled:
		bgm_player.play()
		print("🎵 Music ON")
	else:
		bgm_player.stop()
		print("🔇 Music OFF")

func _ready():
	rng.randomize()
	attack_button.pressed.connect(on_attack_pressed)
	# MVP lock: do not wire skills for now
	# skills_button.pressed.connect(on_skills_pressed)

	bgm_player.volume_db = -6
	sfx_player.volume_db = -6

	turn_order = [
		get_node("/root/BattleScene/Player1"),
		get_node("/root/BattleScene/Player2"),
		get_node("/root/BattleScene/Enemy")
	]

	# setup_skills_menu()  # MVP: disabled
	start_turn()

# MVP lock: whole skills setup disabled
# func setup_skills_menu():z
# 	for child in skills_list.get_children():
# 		if child.name != "BackButton":
# 			child.queue_free()
# 	var back_button = Button.new()
# 	back_button.name = "BackButton"
# 	back_button.text = "Back"
# 	back_button.pressed.connect(func(): hide_skills_menu(); show_action_menu(true); skills_button.grab_focus())
# 	skills_list.add_child(back_button)

func take_damage(amount: int) -> void:
	if is_defeated:
		return

	hp = max(hp - amount, 0)
	print(name, "takes", amount, "damage. HP:", hp)

	var bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")
	if bar:
		# Ensure the HP bar matches enemy's actual HP range
		if bar.max_value != hp_max:
			bar.min_value = 0
			bar.max_value = hp_max
		bar.value = hp
	else:
		push_warning("Enemy HP bar not found at /root/BattleScene/UILayer/EnemyHUD/EnemyHPBar")

	CombatUI.show_damage_popup(self, amount)

	if hp == 0:
		is_defeated = true
		print(name, "has been defeated!")




func start_turn():
	if game_over:
		attack_button.grab_focus()
		return

	current_actor = turn_order[current_turn_index]
	if current_actor.is_defeated:
		end_turn()
		return

	if check_victory():
		game_over = true
		turn_label.text = "VICTORY!"
		return
	elif check_defeat():
		game_over = true
		turn_label.text = "DEFEAT..."
		return

	turn_label.text = current_actor.name + "'s Turn"

	if is_player(current_actor):
		waiting_for_input = true
		show_action_menu(true)
		attack_button.grab_focus()
	else:
		waiting_for_input = false
		show_action_menu(false)
		await get_tree().process_frame

		var enemy := current_actor
		print("[TM] Enemy turn start ->", enemy, " hp:", enemy.get("hp"))

		var tgt: Node = null
		for a in turn_order:
			if is_player(a) and not bool(a.get("is_defeated")):
				tgt = a
				break
		print("[TM] Enemy target ->", tgt)

		if enemy and enemy.has_method("attack") and tgt:
			enemy.attack(tgt)

		end_turn()


func end_turn():
	await get_tree().create_timer(2.0).timeout
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	start_turn()

func on_attack_pressed():
	if not waiting_for_input:
		return
	print("⚔️ Basic attack by:", current_actor.name)
	waiting_for_input = false
	qte_active = true
	show_action_menu(false)

	# Basic attack with QTE — use existing action to avoid InputMap crash
	await get_tree().create_timer(0.5).timeout
	var qte_result = await QTEManager.start_qte("confirm attack", 700, "Time your strike!")  # was "timing"
	var enemy = get_node("/root/BattleScene/Enemy")

	# MVP: don't rely on selected_ability existing on actors
	# current_actor.selected_ability = "basic_attack"

	handle_basic_attack_result(qte_result, enemy)

	qte_active = false
	end_turn()

func handle_basic_attack_result(result: String, target):
	var damage := 0
	match result:
		"crit":
			damage = current_actor.rng.randi_range(20, 30)
			print(current_actor.name + " lands a CRITICAL hit!")
		"normal":
			damage = current_actor.rng.randi_range(10, 15)
			print(current_actor.name + " hits successfully!")
		"fail":
			damage = current_actor.rng.randi_range(3, 5)
			print(current_actor.name + " grazes the target...")

	if damage > 0:
		target.take_damage(damage)

func on_skills_pressed():
	# MVP lock: stubbed out to avoid crashes if pressed
	print("MVP lock: Skills are disabled for now.")
	show_action_menu(true)
	return

func execute_skill(ability_name: String):
	# MVP lock: not used
	print("MVP lock: execute_skill skipped for", ability_name)
	return

func show_action_menu(show: bool):
	action_menu.visible = show

# func show_skills_menu():
# 	if skills_menu: skills_menu.visible = true
# func hide_skills_menu():
# 	if skills_menu: skills_menu.visible = false

func check_victory() -> bool:
	for actor in turn_order:
		if actor.name.begins_with("Enemy") and not actor.is_defeated:
			return false
	return true

func check_defeat() -> bool:
	for actor in turn_order:
		if actor.name.begins_with("Player") and not actor.is_defeated:
			return false
	return true

func is_player(actor: Node) -> bool:
	return actor.name.begins_with("Player")
