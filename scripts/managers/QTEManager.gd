extends Node

signal qte_completed

@onready var qte_container: Control = get_node_or_null("/root/BattleScene/UILayer/QTEContainer")
@onready var qte_circle: Node2D = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTECircle")
@onready var qte_text: Label = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText")
@onready var qte_pressure_bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEPressureBar")
@export var qte_parent_path: NodePath = ^"/root/BattleScene/UILayer/QTEContainer"

var qte_active: bool = false

func _ready() -> void:
	# Only try to set up QTE if we're actually in the battle scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "BattleScene":
		_ensure_qte_container()
		
		# TASK 1: Force hide all QTE UI elements on start
		if qte_container:
			qte_container.visible = false
		if qte_circle:
			qte_circle.visible = false
		if qte_pressure_bar:
			qte_pressure_bar.visible = false
		if qte_text:
			qte_text.visible = false
			qte_text.text = ""
		
		print("[QTE] Ready. parent=%s z=%s" % [
			qte_container if qte_container == null else qte_container.get_path(),
			"?" if qte_container == null else str(qte_container.z_index)
		])
	else:
		print("[QTE] Waiting for BattleScene to load...")

func _ensure_qte_container() -> void:
	# Only try to find QTE elements if we're in the battle scene
	var current_scene = get_tree().current_scene
	if not current_scene or current_scene.name != "BattleScene":
		return
		
	# Refresh references in case scene order changed
	qte_container = get_node_or_null(qte_parent_path) as Control
	qte_circle = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTECircle") as Node2D
	qte_text = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText") as Label
	qte_pressure_bar = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEPressureBar") as ProgressBar

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
	
	# Force hide all elements when ensuring container
	if qte_circle:
		qte_circle.visible = false
	if qte_text:
		qte_text.visible = false
	if qte_pressure_bar:
		qte_pressure_bar.visible = false

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
	
	# Try to refresh QTE container references when actually needed
	_ensure_qte_container()
	
	if qte_container == null:
		print("❌ qte_container is NULL!")
		push_error("[QTE] Cannot start — parent missing.")
		return "fail"
	print("✅ qte_container found, continuing...")

	# Check for Lightning Surge QTE first
	if prompt_text == "Press X rapidly!":
		return await start_lightning_surge_qte(action_name, prompt_text, target_player)
	
	# Check for Phase Slam QTE
	if prompt_text == "Hold X, release on cue!":
		return await start_phase_slam_qte(action_name, prompt_text, target_player)

	# Check for Sniper QTE
	if prompt_text == "Press Z for Big Shot!":
		return await start_sniper_qte(action_name, prompt_text, target_player)

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

	# TASK 1: Use new selective QTE UI system
	show_qte("press", prompt_text, window_ms)
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
			if timing_percentage < 0.4:
				result = "crit"
				print("✨ PERFECT TIMING! CRITICAL!")
				ScreenShake.shake(5.0, 0.4)  # Add screen shake for crits
				if sfx_player and action_name == "confirm attack":
					var current_actor = get_node_or_null("/root/BattleScene/TurnManager").current_actor
					if current_actor and current_actor.name == "Player1":
						# Player1 = Sword Spirit (crit = parry.wav)
						sfx_player.stream = preload("res://assets/sfx/parry.wav")
					elif current_actor and current_actor.name == "Player2":
						# Player2 = Gun Girl (crit = gun2.wav)
						sfx_player.stream = preload("res://assets/sfx/gun2.wav")
					sfx_player.play()
			elif timing_percentage < 0.7:
				result = "normal"
				print("✅ GOOD TIMING! SUCCESS!")
				if sfx_player and action_name == "confirm attack":
					var current_actor = get_node_or_null("/root/BattleScene/TurnManager").current_actor
					if current_actor and current_actor.name == "Player1":
						# Player1 = Sword Spirit (normal = attack.wav)
						sfx_player.stream = preload("res://assets/sfx/attack.wav")
					elif current_actor and current_actor.name == "Player2":
						# Player2 = Gun Girl (normal = gun1.wav)
						sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
			else:
				result = "fail"
				print("⚠️ TOO LATE! WEAK HIT!")
				if sfx_player and action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()

	qte_active = false
	print("[QTE] cleanup done")
	hide_qte()
	return result

# TASK 1: New selective QTE UI functions
func show_qte(qte_type: String, prompt: String, window_ms: int) -> void:
	_ensure_qte_container()
	
	# Show container
	if qte_container:
		qte_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		qte_container.position = Vector2.ZERO
		qte_container.size = get_viewport().get_visible_rect().size
		qte_container.z_index = max(qte_container.z_index, 100)
		qte_container.visible = true
		qte_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# TASK 1 & TASK 3: Show only relevant UI for QTE type
	if qte_circle:
		qte_circle.visible = (qte_type == "press")
		if qte_type == "press":
			var screen_center = get_viewport().get_visible_rect().size / 2
			qte_circle.position = screen_center
			qte_circle.scale = Vector2(0.15, 0.15)
	
	if qte_pressure_bar:
		qte_pressure_bar.visible = (qte_type == "hold_release")
		if qte_type == "hold_release":
			# TASK 3: Set z-index and ensure proper layering
			qte_pressure_bar.z_index = 0
			qte_pressure_bar.min_value = 0
			qte_pressure_bar.max_value = 100
			qte_pressure_bar.value = 0
			qte_pressure_bar.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
	
	if qte_text:
		qte_text.visible = true
		qte_text.text = prompt
		# TASK 3: Set z-index to render above pressure bar
		qte_text.z_index = 5
		print("Phase Slam UI -> text z:", qte_text.z_index, " bar z:", qte_pressure_bar.z_index if qte_pressure_bar else "N/A")

func hide_qte() -> void:
	if qte_container:
		qte_container.visible = false
	if qte_circle:
		qte_circle.visible = false
	if qte_pressure_bar:
		qte_pressure_bar.visible = false
		qte_pressure_bar.modulate = Color.WHITE  # Reset color
	if qte_text:
		qte_text.visible = false

func start_lightning_surge_qte(action_name: String, prompt_text: String, target_player = null) -> String:
	print("⚡ Lightning Surge QTE started - 3 hits needed!")
	
	# TASK 2: Show enemy attack animation IMMEDIATELY before QTE
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("attack_animation") and target_player:
		enemy.attack_animation(target_player)
		print("⚡ Enemy pose swapped BEFORE QTE sequence")
	
	qte_active = true
	_ensure_qte_container()
	
	var hits_needed = 3
	var hits_count = 0
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# Define the 3 sub-windows: 0.0-0.5s, 0.75-1.25s, 1.5-2.0s
	var windows = [
		{"start": 0.0, "end": 0.5},
		{"start": 0.75, "end": 1.25}, 
		{"start": 1.5, "end": 2.0}
	]
	
	var start_time = Time.get_ticks_msec()
	var total_duration = 2000  # 2 seconds total
	var current_window = 0
	
	# Show QTE UI using new method
	show_qte("press", prompt_text, total_duration)
	
	# Hide circle initially for lightning surge
	if qte_circle:
		qte_circle.visible = false
	
	while Time.get_ticks_msec() - start_time < total_duration:
		var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0  # Convert to seconds
		
		# Check if we're in a valid input window
		var in_window = false
		var window_progress = 0.0
		
		if current_window < windows.size():
			var window = windows[current_window]
			if elapsed_time >= window.start and elapsed_time <= window.end:
				in_window = true
				# Calculate progress within this window (1.0 to 0.0)
				window_progress = 1.0 - ((elapsed_time - window.start) / (window.end - window.start))
				
				# Show and scale the circle
				if qte_circle:
					qte_circle.visible = true
					qte_circle.scale = Vector2(0.15 * window_progress, 0.15 * window_progress)
			else:
				# Hide circle when not in window
				if qte_circle:
					qte_circle.visible = false
		
		# Update text feedback
		if qte_text:
			if in_window:
				qte_text.text = prompt_text + " (" + str(hits_count) + "/" + str(hits_needed) + ") - WINDOW " + str(current_window + 1)
			else:
				qte_text.text = prompt_text + " (" + str(hits_count) + "/" + str(hits_needed) + ") - WAIT..."
		
		# Check for input during valid window
		if in_window and Input.is_action_just_pressed(action_name):
			hits_count += 1
			current_window += 1
			print("⚡ Lightning hit " + str(hits_count) + "/3!")
			
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/parry.wav")
				sfx_player.play()
			
			if target_player != null and target_player.has_method("show_block_animation"):
				target_player.show_block_animation()
			
			# Check if all hits completed
			if hits_count >= hits_needed:
				break
		
		await get_tree().process_frame
	
	qte_active = false
	hide_qte()
	
	# Determine result
	var result = "fail"
	if hits_count >= hits_needed:
		result = "normal"  # Success for Lightning Surge
		print("⚡ Lightning Surge SUCCESS! All 3 hits landed!")
	else:
		print("❌ Lightning Surge FAILED! Only " + str(hits_count) + "/3 hits")
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()
	
	return result

func start_phase_slam_qte(action_name: String, prompt_text: String, target_player = null) -> String:
	print("💥 Phase Slam QTE started - hold and release!")
	
	# TASK 2: Show enemy attack animation IMMEDIATELY before QTE
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("attack_animation") and target_player:
		enemy.attack_animation(target_player)
		print("💥 Enemy pose swapped BEFORE Phase Slam QTE")
	
	qte_active = true
	_ensure_qte_container()
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# GUSTAVE voiceline spot
	if sfx_player:
		print("🎵 GUSTAVE!! PARRY IT!! (voiceline placeholder)")
	
	# Dramatic pause for voiceline
	await get_tree().create_timer(1.0).timeout
	
	# TASK 1 & TASK 3: Show QTE UI using new selective method
	show_qte("hold_release", prompt_text, 900)
	
	var start_time = Time.get_ticks_msec()
	var fill_duration = 900  # 0.9 seconds to fill
	var is_holding = false
	var release_detected = false
	var release_time = 0
	
	# Wait for initial press
	if qte_text:
		qte_text.text = prompt_text + " - PRESS AND HOLD X!"
	
	while not is_holding:
		if Input.is_action_just_pressed(action_name):
			is_holding = true
			start_time = Time.get_ticks_msec()  # Reset timer when they start holding
			print("💥 Holding X - pressure building!")
			break
		await get_tree().process_frame
	
	# Filling phase - bar fills from top to bottom
	while Time.get_ticks_msec() - start_time < fill_duration:
		var elapsed = Time.get_ticks_msec() - start_time
		var progress = float(elapsed) / float(fill_duration)
		
		if qte_pressure_bar:
			qte_pressure_bar.value = progress * 100
			
			# Color change in final zone (90-100%)
			if progress >= 0.9:
				# Flash red in release zone
				qte_pressure_bar.modulate = Color.RED if (Time.get_ticks_msec() % 200) < 100 else Color.WHITE
				if qte_text:
					qte_text.text = prompt_text + " - RELEASE NOW!"
			else:
				qte_pressure_bar.modulate = Color.WHITE
				if qte_text:
					qte_text.text = prompt_text + " - HOLD... (" + str(int(progress * 100)) + "%)"
		
		# Check if they released
		if Input.is_action_just_released(action_name):
			release_detected = true
			release_time = Time.get_ticks_msec() - start_time
			break
		
		# Check if they stopped holding
		if not Input.is_action_pressed(action_name):
			print("💥 Released X too early!")
			break
			
		await get_tree().process_frame
	
	# If they never released, count as release at 100%
	if not release_detected and Input.is_action_pressed(action_name):
		release_time = fill_duration
		release_detected = true
		print("💥 Time up - forced release!")
	
	qte_active = false
	hide_qte()
	
	# Determine result based on release timing
	var result = "fail"
	if release_detected:
		var release_percentage = float(release_time) / float(fill_duration)
		
		if release_percentage >= 0.9 and release_percentage <= 1.0:
			result = "normal"
			print("💥 PHASE SLAM SUCCESS! Perfect release at " + str(int(release_percentage * 100)) + "%!")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/parry.wav")
				sfx_player.play()
			if target_player != null and target_player.has_method("show_block_animation"):
				target_player.show_block_animation()
		else:
			print("💥 PHASE SLAM FAILED! Released at " + str(int(release_percentage * 100)) + "% (need 90-100%)")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/miss.wav")
				sfx_player.play()
	else:
		print("💥 PHASE SLAM FAILED! Never pressed or held properly!")
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()
	
	return result

func start_sniper_qte(action_name: String, prompt_text: String, target_player = null) -> String:
	print("🎯 Sniper QTE started - line up the shot!")
	
	qte_active = true
	_ensure_qte_container()
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# Show QTE UI using new method
	show_qte("press", prompt_text, 3000)  # 3 second window
	
	# Hide the default circle - we're using custom elements
	if qte_circle:
		qte_circle.visible = false
	
	# Create sweet spot (stationary center target)
	var sweet_spot = ColorRect.new()
	sweet_spot.size = Vector2(20, 20)
	sweet_spot.color = Color.RED
	var screen_center = get_viewport().get_visible_rect().size / 2
	sweet_spot.position = screen_center - sweet_spot.size / 2
	qte_container.add_child(sweet_spot)
	
	# Create crosshair (moving)
	var crosshair = ColorRect.new()
	crosshair.size = Vector2(40, 4)
	crosshair.color = Color.WHITE
	crosshair.position = Vector2(50, screen_center.y - 2)  # Start from left side
	qte_container.add_child(crosshair)
	
	# Movement variables
	var start_time = Time.get_ticks_msec()
	var duration = 1500  # 3 seconds total
	var screen_width = get_viewport().get_visible_rect().size.x
	var movement_distance = screen_width - 90  # Account for crosshair width + margins
	var movement_speed = movement_distance / (duration / 1000.0)  # pixels per second
	
	var input_detected = false
	var hit_result = "fail"
	
	# Movement loop
	while Time.get_ticks_msec() - start_time < duration:
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		
		# Move crosshair across screen
		crosshair.position.x = 50 + (elapsed * movement_speed)
		
		# Update text
		if qte_text:
			qte_text.text = prompt_text + " - Line up the shot!"
		
		# Check for input
		if Input.is_action_just_pressed(action_name):
			input_detected = true
			
			# Check hit detection
			var crosshair_center_x = crosshair.position.x + crosshair.size.x / 2
			var sweet_spot_center_x = sweet_spot.position.x + sweet_spot.size.x / 2
			var distance = abs(crosshair_center_x - sweet_spot_center_x)
			
			if distance <= 5:  # Center zone (±5px)
				hit_result = "crit"
				print("🎯 PERFECT SNIPER SHOT! Bullseye!")
			elif distance <= 15:  # Outer zone (±15px)
				hit_result = "normal"
				print("🎯 Good sniper shot! Hit the target!")
			else:
				hit_result = "fail"
				print("💨 Sniper shot missed the target...")
			
			break
		
		await get_tree().process_frame
	
	# Clean up
	sweet_spot.queue_free()
	crosshair.queue_free()
	qte_active = false
	hide_qte()
	
	# Play feedback sound
	if sfx_player:
		match hit_result:
			"crit":
				sfx_player.stream = preload("res://assets/sfx/gun2.wav")
				sfx_player.play()
			"normal":
				sfx_player.stream = preload("res://assets/sfx/gun2.wav")
				sfx_player.play()
			"fail":
				sfx_player.stream = preload("res://assets/sfx/miss.wav")
				sfx_player.play()
	
	return hit_result
