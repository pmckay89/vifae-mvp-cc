extends Node

signal qte_completed

@onready var qte_container = get_node("/root/BattleScene/UILayer/QTEContainer")
@onready var qte_circle = get_node("/root/BattleScene/UILayer/QTEContainer/QTECircle")
@onready var qte_text = get_node("/root/BattleScene/UILayer/QTEContainer/QTEText")

var qte_active: bool = false

func start_qte_for_ability(player, ability_name: String, target):
	# Determine QTE parameters based on ability
	var qte_type = "confirm attack"
	var window_ms = 500
	var prompt = "Press Z!"
	
	# Customize QTE based on ability
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
	player.on_qte_result(result, target)
	
	# Emit completion signal
	qte_completed.emit()

func start_qte(action_name: String, window_ms: Variant = 700, prompt_text: String = "Press Z!", target_player = null) -> String:
	qte_active = true

	# Handle difficulty labels like "normal", "hard"
	var timing_presets := {
		"easy": 1000,
		"normal": 700,
		"hard": 400,
		"very_hard": 250
	}

	if typeof(window_ms) == TYPE_STRING:
		window_ms = timing_presets.get(window_ms, 700)

	# Show and animate the QTE UI
	show_qte_ui(prompt_text, window_ms)
	print("🎯 QTE WINDOW - " + prompt_text)

	var start_time = Time.get_ticks_msec()
	var end_time = start_time + window_ms
	var input_detected = false
	var input_time = 0

	var sfx_player = get_node("/root/BattleScene/SFXPlayer")

	while Time.get_ticks_msec() < end_time:
		var time_left = end_time - Time.get_ticks_msec()
		var progress = float(time_left) / float(window_ms)
		qte_circle.scale = Vector2(0.15 * progress, 0.15 * progress)

		if Input.is_action_just_pressed(action_name):
			input_detected = true
			input_time = Time.get_ticks_msec() - start_time

			if action_name == "parry":
				sfx_player.stream = preload("res://assets/sfx/parry.wav")
				sfx_player.play()
				if target_player != null:
					target_player.show_block_animation()
			break

		await get_tree().process_frame

	hide_qte_ui()

	var result = "fail"

	if input_detected:
		var timing_percentage = float(input_time) / float(window_ms)

		if action_name == "parry":
			result = "normal"
			print("✅ PARRY SUCCESS!")
		else:
			if timing_percentage < 0.2:
				result = "crit"
				print("✨ PERFECT TIMING! CRITICAL!")
				if action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/crit.wav")
					sfx_player.play()
			elif timing_percentage < 0.6:
				result = "normal"
				print("✅ GOOD TIMING! SUCCESS!")
				if action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
					sfx_player.play()
			else:
				result = "fail"
				print("⚠️ TOO LATE! WEAK HIT!")
				if action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
	else:
		result = "fail"
		print("❌ QTE FAILED! NO INPUT!")

		if action_name == "confirm attack" or action_name == "parry":
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()

	qte_active = false
	return result

func show_qte_ui(prompt: String, duration_ms: int):
	# Set text
	qte_text.text = prompt
	
	# Show container
	qte_container.visible = true
	
	# Reset circle scale for the animation
	qte_circle.scale = Vector2(0.15, 0.15)

func hide_qte_ui():
	qte_container.visible = false

func shake_circle():
	# Quick shake animation on success
	var tween = create_tween()
	var original_pos = qte_circle.position
	tween.tween_property(qte_circle, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(qte_circle, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(qte_circle, "position", original_pos, 0.05)

# Compatibility function for existing parry system
func start_parry_qte(target_player, difficulty = "normal") -> bool:
	var timing_presets := {
		"easy": 1000,
		"normal": 500,
		"hard": 300,
		"very_hard": 200
	}

	var window_ms = difficulty
	if typeof(difficulty) == TYPE_STRING:
		window_ms = timing_presets.get(difficulty, 500)

	var result = await start_qte("parry", window_ms, "Press X to parry!", target_player)
	return result != "fail"
