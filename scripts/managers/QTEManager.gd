extends Node

signal qte_completed

@onready var qte_container: Control = get_node_or_null("/root/BattleScene/UILayer/QTEContainer")
@onready var qte_circle: Node2D = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTECircle")
@onready var qte_text: Label = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText")
@export var qte_parent_path: NodePath = ^"/root/BattleScene/UILayer/QTEContainer"

var qte_active: bool = false



func _ready() -> void:
	_ensure_qte_container()
	if qte_text:
		qte_text.text = ""
	print("[QTE] Ready. parent=%s z=%s" % [
		qte_container if qte_container == null else qte_container.get_path(),
		"?" if qte_container == null else str(qte_container.z_index)
	])

func _ensure_qte_container() -> void:
	# Refresh references in case scene order changed
	qte_container = get_node_or_null(qte_parent_path) as Control
	qte_circle = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTECircle") as Node2D
	qte_text = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText") as Label

	if qte_container == null:
		push_error("[QTE] Missing parent: %s" % str(qte_parent_path))
		return

	# Make sure it renders above other UI and fills the viewport
	qte_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	qte_container.position = Vector2.ZERO
	qte_container.size = get_viewport().get_visible_rect().size
	qte_container.z_index = max(qte_container.z_index, 100)
	qte_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_container.visible = false

func start_qte_for_ability(player, ability_name: String, target):
	# Determine QTE parameters based on ability
	var qte_type := "confirm attack"
	var window_ms := 500
	var prompt := "Press Z!"

	match ability_name:
		"blade_rush", "sniper_shot":
			qte_type = "confirm attack"
			window_ms = 400
			prompt = "Press Z for precision!"
		"spirit_slash", "explosive_round":
			qte_type = "confirm attack"
			window_ms = 300
			prompt = "Press Z at the perfect moment!"
		"whirlwind", "rapid_fire":
			qte_type = "confirm attack"
			window_ms = 600
			prompt = "Press Z to unleash!"
		_:
			qte_type = "confirm attack"
			window_ms = 500
			prompt = "Press Z!"

	# Run the QTE
	var result = await start_qte(qte_type, window_ms, prompt, null)

	# Pass result to player
	if player and player.has_method("on_qte_result"):
		player.on_qte_result(result, target)

	# Emit completion signal
	qte_completed.emit()

func start_qte(action_name: String, window_ms: int = 700, prompt_text: String = "Press Z!", target_player = null) -> String:
	print("🔧 start_qte called with:", action_name, prompt_text)
	if qte_container == null:
		print("❌ qte_container is NULL!")
		push_error("[QTE] Cannot start — parent missing.")
		return "fail"
	print("✅ qte_container found, continuing...")

	qte_active = true

	var timing_presets := {
		"easy": 1000,
		"normal": 700,
		"hard": 400,
		"very_hard": 250
	}

	if typeof(window_ms) == TYPE_STRING:
		window_ms = int(timing_presets.get(window_ms, 700))
	else:
		window_ms = int(window_ms)

	# Show and animate the QTE UI
	show_qte_ui(prompt_text, window_ms)

	# Show and animate the QTE UI
	show_qte_ui(prompt_text, window_ms)
	print("[QTE] spawn @%s parent=%s z=%d" % [
		qte_container.get_path(),
		qte_container.get_parent().get_path(),
		qte_container.z_index
	])
	print("🎯 QTE WINDOW - " + prompt_text)

	var start_time := Time.get_ticks_msec()
	var end_time := start_time + window_ms
	var input_detected := false
	var input_time := 0

	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")

	while Time.get_ticks_msec() < end_time:
		var time_left := end_time - Time.get_ticks_msec()
		var progress := float(time_left) / float(window_ms)
		if qte_circle:
			qte_circle.scale = Vector2(0.15 * progress, 0.15 * progress)

		if Input.is_action_just_pressed(action_name):
			input_detected = true
			input_time = Time.get_ticks_msec() - start_time

			if action_name == "parry":
				if sfx_player:
					sfx_player.stream = preload("res://assets/sfx/parry.wav")
					sfx_player.play()
				if target_player != null and target_player.has_method("show_block_animation"):
					target_player.show_block_animation()
			break

		await get_tree().process_frame

	var result := "fail"
	if input_detected:
		var timing_percentage := float(input_time) / float(window_ms)
		if action_name == "parry":
			result = "normal"
			print("✅ PARRY SUCCESS!")
		else:
			if timing_percentage < 0.2:
				result = "crit"
				print("✨ PERFECT TIMING! CRITICAL!")
				if sfx_player and action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
			elif timing_percentage < 0.6:
				result = "normal"
				print("✅ GOOD TIMING! SUCCESS!")
				if sfx_player and action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
			else:
				result = "fail"
				print("⚠️ TOO LATE! WEAK HIT!")
				if sfx_player and action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
	else:
		result = "fail"
		print("❌ QTE FAILED! NO INPUT!")
		if sfx_player and (action_name == "confirm attack" or action_name == "parry"):
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

	qte_active = false
	print("[QTE] cleanup done")
	hide_qte_ui()
	return result

func show_qte_ui(prompt: String, duration_ms: int) -> void:
	_ensure_qte_container()
	
	if qte_container:
		qte_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		qte_container.position = Vector2.ZERO
		qte_container.size = get_viewport().get_visible_rect().size
		qte_container.z_index = max(qte_container.z_index, 100)
		qte_container.visible = true
		qte_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if qte_text:
		qte_text.text = prompt

	if qte_circle:
		qte_circle.scale = Vector2(0.15, 0.15)

func hide_qte_ui() -> void:
	if qte_container:
		qte_container.visible = false
