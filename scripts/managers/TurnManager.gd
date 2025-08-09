extends Node

var turn_order: Array = []
var current_turn_index: int = 0
var game_over: bool = false
var current_actor: Node = null
var waiting_for_input: bool = false
var qte_active: bool = false

@onready var turn_label := get_node("../UILayer/TurnLabel")
@onready var attack_button := get_node("/root/BattleScene/UILayer/ActionMenu/AttackButton")
@onready var skills_button := get_node("/root/BattleScene/UILayer/ActionMenu/SkillsButton")
@onready var action_menu := get_node("/root/BattleScene/UILayer/ActionMenu")
@onready var bgm_player := get_node("../BGMPlayer")
@onready var sfx_player := get_node("../SFXPlayer")
var music_enabled := true

func _unhandled_input(event):
	if event.is_action_pressed("confirm attack") and waiting_for_input and not qte_active:
		on_attack_pressed()
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
	attack_button.pressed.connect(on_attack_pressed)
	# Skills not MVP — keep connected but function is a no-op
	skills_button.pressed.connect(on_skills_pressed)

	# volumes
	bgm_player.volume_db = -6
	sfx_player.volume_db = -6

	# turn order
	turn_order = [
		get_node("/root/BattleScene/Player1"),
		get_node("/root/BattleScene/Player2"),
		get_node("/root/BattleScene/Enemy")
	]

	start_turn()

func start_turn():
	if game_over:
		attack_button.grab_focus()
		return

	current_actor = turn_order[current_turn_index]
	if bool(current_actor.get("is_defeated")):
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

		# brief telegraph so the Enemy turn is visible
		await get_tree().create_timer(2.5).timeout

		var enemy := current_actor
		var alive_players = []
		for a in turn_order:
			if is_player(a) and not bool(a.get("is_defeated")):
				alive_players.append(a)

		var tgt: Node = null
		if alive_players.size() > 0:
			tgt = alive_players[randi() % alive_players.size()]  # Random target!

		if enemy and enemy.has_method("attack") and tgt:
			enemy.attack(tgt)

		end_turn()


func end_turn():
	await get_tree().create_timer(0.6).timeout
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	start_turn()

func on_attack_pressed():
	if not waiting_for_input or qte_active:
		return

	print("⚔️ Basic attack by:", current_actor.name)
	waiting_for_input = false
	qte_active = true
	show_action_menu(false)

	# Small windup
	await get_tree().create_timer(0.3).timeout

	# Use an existing action to avoid InputMap errors ("confirm attack" instead of "timing")
	# Signature: start_qte(action_name: String, window_ms: int, prompt: String) -> String ("crit","normal","fail")
	var qte_result := await QTEManager.start_qte("confirm attack", 700, "Time your strike!")
	var enemy := get_node("/root/BattleScene/Enemy")

	handle_basic_attack_result(qte_result, enemy)

	qte_active = false
	end_turn()

func handle_basic_attack_result(result: String, target):
	var damage := 0
	match result:
		"crit":
			if current_actor.has_node("."): # dummy to keep rng access identical if you use it
				damage = current_actor.rng.randi_range(20, 30)
			else:
				damage = randi_range(20, 30)
			print(current_actor.name + " lands a CRITICAL hit!")
		"normal":
			if current_actor.has_node("."):
				damage = current_actor.rng.randi_range(10, 15)
			else:
				damage = randi_range(10, 15)
			print(current_actor.name + " hits successfully!")
		"fail":
			if current_actor.has_node("."):
				damage = current_actor.rng.randi_range(3, 5)
			else:
				damage = randi_range(3, 5)
			print(current_actor.name + " grazes the target...")

	if damage > 0 and target and target.has_method("take_damage"):
		target.take_damage(damage)

func on_skills_pressed():
	# Not MVP — do nothing for now
	return

func show_action_menu(show: bool):
	action_menu.visible = show

func check_victory() -> bool:
	for actor in turn_order:
		if actor.name.begins_with("Enemy"):
			if not bool(actor.get("is_defeated")):
				return false
	return true


func check_defeat() -> bool:
	for actor in turn_order:
		if actor.name.begins_with("Player"):
			if not bool(actor.get("is_defeated")):
				return false
	return true

func is_player(actor: Node) -> bool:
	return actor.name.begins_with("Player")
