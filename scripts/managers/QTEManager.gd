extends Node

signal qte_completed

@onready var qte_container: Control = get_node_or_null("/root/BattleScene/UILayer/QTEContainer")
@onready var qte_circle: Node2D = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTECircle")
@onready var qte_fill_ring: Node2D = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEFillRing")
@onready var qte_text: Label = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText")
@onready var qte_pressure_bar: ProgressBar = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEPressureBar")
@onready var qte_widget: QTEWidget = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEWidget")
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
			"null" if qte_container == null else str(qte_container.get_path()),
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
	qte_fill_ring = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEFillRing") as Node2D
	qte_text = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEText") as Label
	qte_pressure_bar = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEPressureBar") as ProgressBar
	qte_widget = get_node_or_null("/root/BattleScene/UILayer/QTEContainer/QTEWidget") as QTEWidget
	
	# Create QTEWidget dynamically if it doesn't exist (only once)
	if qte_widget == null and qte_container != null:
		# Check if it already exists as a child first
		for child in qte_container.get_children():
			if child.name == "QTEWidget":
				qte_widget = child as QTEWidget
				print("[QTE] Found existing QTEWidget")
				break
		
		# If still not found, create it
		if qte_widget == null:
			qte_widget = preload("res://scripts/ui/QTEWidget.gd").new()
			qte_widget.name = "QTEWidget"
			qte_container.add_child(qte_widget)
			print("[QTE] Created QTEWidget dynamically")

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
		"moonfall_slash":
			# Special rapid-press QTE
			var hit_count = await start_rapid_press_qte("Press Z as fast as possible!")
			if player and player.has_method("on_qte_result"):
				player.on_qte_result(str(hit_count), target)
			qte_completed.emit()
			return
		"big_shot":
			qte_type = "confirm attack"
			window_ms = 400
			prompt = "Press Z for Big Shot!"
		"scatter_shot":
			qte_type = "confirm attack"
			window_ms = 600
			prompt = "Guide reticle through all targets!"
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

	# Check for attack QTEs - now use enhanced ring system with precision timing
	if prompt_text in ["Press Z to attack!", "Press Z for precision!", "Press Z at the perfect moment!", "Press Z to unleash!"]:
		print("⚔️ Attack QTE - using enhanced ring system with precision timing!")
		# Use the enhanced ring system but fall through to existing QTE logic

	# Check for Lightning Surge QTE first
	if prompt_text == "Press X rapidly!":
		return await start_lightning_surge_qte(action_name, prompt_text, target_player)
	
	# Check for Phase Slam QTE
	if prompt_text == "Hold X, release on cue!":
		return await start_phase_slam_qte(action_name, prompt_text, target_player)

	# Check for Sniper QTE
	if prompt_text == "Press Z for Big Shot!":
		return await start_sniper_qte(action_name, prompt_text, target_player)
	
	# Check for Scatter Shot QTE (uses new sniper box system)
	if prompt_text == "Guide reticle through all targets!":
		var enemy = get_node_or_null("/root/BattleScene/Enemy")
		if enemy:
			return await start_sniper_box_qte(enemy.global_position)
		else:
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
		var fill_progress := 1.0 - progress  # Fill ring grows as time progresses (0.0 to 1.0)
		
		# EMPTY ring stays static (target boundary)
		if qte_circle:
			qte_circle.scale = Vector2(0.15, 0.15)  # Always static size
		
		# FILL ring grows from tiny to beyond EMPTY ring size (gives timing leeway)
		if qte_fill_ring:
			var fill_scale = 0.02 + (fill_progress * 0.18)  # Grows from 0.02 to 0.20 (beyond empty ring at 0.15)
			qte_fill_ring.scale = Vector2(fill_scale, fill_scale)

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
			_safe_audio_call("play_qte_success")
		else:
			# NEW PRECISION-BASED TIMING for attacks (aligns with ring visual)
			# Perfect timing: when fill ring is close to empty ring size (75-85% of window)
			if timing_percentage >= 0.75 and timing_percentage <= 0.85:
				result = "crit"
				print("✨ PERFECT RING TIMING! CRITICAL!")
				_safe_audio_call("play_qte_success")
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
			# Good timing: close to perfect or slightly after (65-75% and 85-95%)
			elif (timing_percentage >= 0.65 and timing_percentage < 0.75) or (timing_percentage > 0.85 and timing_percentage <= 0.95):
				result = "normal"
				print("✅ GOOD RING TIMING! SUCCESS!")
				_safe_audio_call("play_qte_success")
				if sfx_player and action_name == "confirm attack":
					var current_actor = get_node_or_null("/root/BattleScene/TurnManager").current_actor
					if current_actor and current_actor.name == "Player1":
						# Player1 = Sword Spirit (normal = attack.wav)
						sfx_player.stream = preload("res://assets/sfx/attack.wav")
					elif current_actor and current_actor.name == "Player2":
						# Player2 = Gun Girl (normal = gun1.wav)
						sfx_player.stream = preload("res://assets/sfx/gun1.wav")
					sfx_player.play()
			# Poor timing: too early or too late (0-65% or 95-100%)
			else:
				result = "fail"
				print("⚠️ POOR RING TIMING! WEAK HIT!")
				_safe_audio_call("play_qte_fail")
				if sfx_player and action_name == "confirm attack":
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
	else:
		# No input detected - timeout fail
		_safe_audio_call("play_qte_fail")

	qte_active = false
	print("[QTE] cleanup done")
	hide_qte()
	return result

# TASK 1: New selective QTE UI functions
func show_qte(qte_type: String, prompt: String, _window_ms: int) -> void:
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
			qte_circle.scale = Vector2(0.15, 0.15)  # STATIC size - target boundary
			
			# Load custom ring texture if available, fallback to existing
			var ring_empty_texture = load("res://assets/ui/qte_ring_empty.png")
			if ring_empty_texture != null:
				qte_circle.texture = ring_empty_texture
				print("[QTE] Using custom ring empty texture")
	
	# Show fill ring for press QTEs
	if qte_fill_ring:
		qte_fill_ring.visible = (qte_type == "press")
		if qte_type == "press":
			var screen_center = get_viewport().get_visible_rect().size / 2
			qte_fill_ring.position = screen_center
			qte_fill_ring.scale = Vector2(0.02, 0.02)  # Start very small (nearly invisible)
			
			# Load custom fill texture if available, fallback to existing with green tint
			var ring_fill_texture = load("res://assets/ui/qte_ring_fill.png")
			if ring_fill_texture != null:
				qte_fill_ring.texture = ring_fill_texture
				qte_fill_ring.modulate = Color.WHITE  # Remove tint if custom texture
				print("[QTE] Using custom ring fill texture")
			else:
				qte_fill_ring.modulate = Color(0, 1, 0, 0.7)  # Green tint for existing texture
	
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
		print("Phase Slam UI -> text z:", qte_text.z_index, " bar z:", str(qte_pressure_bar.z_index) if qte_pressure_bar else "N/A")

func hide_qte() -> void:
	if qte_container:
		qte_container.visible = false
	if qte_circle:
		qte_circle.visible = false
	if qte_fill_ring:
		qte_fill_ring.visible = false
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
		enemy.attack_animation(target_player, "lightning_surge")
		print("⚡ Enemy pose swapped BEFORE QTE sequence")
	
	qte_active = true
	_ensure_qte_container()
	
	var hits_needed = 3
	var hits_count = 0
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# Define the 3 sub-windows: More generous timing windows
	var windows = [
		{"start": 0.0, "end": 0.7},      # Window 1: 0.7s duration (was 0.5s)
		{"start": 0.9, "end": 1.6},     # Window 2: 0.7s duration (was 0.5s)
		{"start": 1.8, "end": 2.5}      # Window 3: 0.7s duration (was 0.5s)
	]
	
	var start_time = Time.get_ticks_msec()
	var total_duration = 2700  # 2.7 seconds total (was 2.0s)
	var current_window = 0
	var window_results = []  # Track timing quality for each window
	
	# Show QTE UI using new ring method
	show_qte("press", prompt_text, total_duration)
	
	# Set up static empty ring for lightning surge
	if qte_circle:
		var screen_center = get_viewport().get_visible_rect().size / 2
		qte_circle.position = screen_center
		qte_circle.scale = Vector2(0.15, 0.15)  # Static target size
		qte_circle.visible = false  # Hide initially, show per window
	
	# Set up fill ring for lightning surge  
	if qte_fill_ring:
		var screen_center = get_viewport().get_visible_rect().size / 2
		qte_fill_ring.position = screen_center
		qte_fill_ring.scale = Vector2(0.02, 0.02)  # Start small
		qte_fill_ring.visible = false  # Hide initially, show per window
	
	while Time.get_ticks_msec() - start_time < total_duration:
		var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0  # Convert to seconds
		
		# Check if we're in a valid input window
		var in_window = false
		var window_progress = 0.0
		
		if current_window < windows.size():
			var window = windows[current_window]
			if elapsed_time >= window.start and elapsed_time <= window.end:
				in_window = true
				# Calculate progress within this window (0.0 to 1.0)
				window_progress = (elapsed_time - window.start) / (window.end - window.start)
				
				# Show rings and animate fill ring growth
				if qte_circle:
					qte_circle.visible = true
					qte_circle.scale = Vector2(0.15, 0.15)  # Static empty ring
				
				if qte_fill_ring:
					qte_fill_ring.visible = true
					# Fill ring grows from 0.02 to 0.20 over window duration
					var fill_scale = 0.02 + (window_progress * 0.18)
					qte_fill_ring.scale = Vector2(fill_scale, fill_scale)
				
				# Play incoming.wav at the very start of each window
				if window_progress < 0.05:  # Just entered the window
					if not get_meta("window_" + str(current_window) + "_sound_played", false):
						if sfx_player:
							sfx_player.stream = preload("res://assets/sfx/incoming.wav")
							sfx_player.play()
							print("🚨 Playing incoming.wav for lightning window " + str(current_window + 1))
						set_meta("window_" + str(current_window) + "_sound_played", true)
			else:
				# Hide rings when not in window
				if qte_circle:
					qte_circle.visible = false
				if qte_fill_ring:
					qte_fill_ring.visible = false
		
		# Update text feedback - keep it simple
		if qte_text:
			qte_text.text = "PARRY THE LIGHTNING STRIKES! (X)"
		
		# Check for input during valid window
		if in_window and Input.is_action_just_pressed(action_name):
			hits_count += 1
			
			# Late-timing parry system: 30-100% = successful parry
			var window_timing_result = "fail"
			if window_progress >= 0.7 and window_progress <= 1.0:
				window_timing_result = "perfect"  # 70-100% = perfect (late timing)
				print("⚡ PERFECT Lightning parry " + str(hits_count) + "/3! (0 damage)")
			elif window_progress >= 0.3 and window_progress < 0.7:
				window_timing_result = "normal"   # 30-70% = normal (middle timing)
				print("⚡ NORMAL Lightning parry " + str(hits_count) + "/3! (0 damage)")
			else:
				window_timing_result = "fail"     # 0-30% = fail (too early)
				print("⚡ FAILED Lightning parry " + str(hits_count) + "/3! (10 damage)")
			
			window_results.append(window_timing_result)
			current_window += 1
			
			# Successful parry sound and animation
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/parry.wav")
				sfx_player.play()
			
			if target_player != null and target_player.has_method("show_block_animation"):
				target_player.show_block_animation(0.2)  # Short block for rapid lightning hits
			
			# Check if all hits completed
			if hits_count >= hits_needed:
				break
		
		# Check if window ended without successful input (failed parry)
		elif current_window < windows.size():
			var window = windows[current_window]
			if elapsed_time > window.end and current_window == hits_count:
				# Player failed this window
				print("❌ Lightning window " + str(current_window + 1) + " failed!")
				window_results.append("missed")  # Track missed windows
				
				# Play miss sound for failed window
				if sfx_player:
					sfx_player.stream = preload("res://assets/sfx/miss.wav")
					sfx_player.play()
				
				current_window += 1
		
		await get_tree().process_frame
	
	qte_active = false
	hide_qte()
	
	# Calculate damage based on individual strike results
	var successful_parries = 0
	var failed_strikes = 0
	
	for window_result in window_results:
		match window_result:
			"perfect", "normal": successful_parries += 1  # Both count as successful
			"fail": failed_strikes += 1                   # Failed timing = damage
			"missed": failed_strikes += 1                 # Missed window = damage
	
	# Add any completely missed windows (didn't press at all)
	var total_missed_windows = 3 - window_results.size()
	failed_strikes += total_missed_windows
	
	# Return result with damage count
	var result = str(failed_strikes)  # Return number of strikes that hit (0, 1, 2, or 3)
	
	if failed_strikes == 0:
		print("⚡ Lightning Surge SUCCESS! All strikes parried! (0 damage)")
	else:
		print("⚡ Lightning Surge: " + str(failed_strikes) + "/3 strikes hit for " + str(failed_strikes * 10) + " damage")
		if sfx_player and failed_strikes > 0:
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()
	
	return result

func start_phase_slam_qte(action_name: String, prompt_text: String, target_player = null) -> String:
	print("💥 Phase Slam QTE started - hold and release!")
	
	# TASK 2: Show enemy attack animation IMMEDIATELY before QTE
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("attack_animation") and target_player:
		enemy.attack_animation(target_player, "phase_slam")
		print("💥 Enemy pose swapped BEFORE Phase Slam QTE")
	
	qte_active = true
	_ensure_qte_container()
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
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
			
			# Visual urgency: color changes as bar fills
			if progress >= 0.8:
				# Flash green in release zone (80-100%) - GOOD timing
				var style_box = StyleBoxFlat.new()
				if (Time.get_ticks_msec() % 200) < 100:
					style_box.bg_color = Color.LIME_GREEN
				else:
					style_box.bg_color = Color.WHITE
				qte_pressure_bar.add_theme_stylebox_override("fill", style_box)
				if qte_text:
					qte_text.text = prompt_text + " - RELEASE NOW!"
			elif progress >= 0.6:
				# Yellow warning zone (60-80%) - getting close
				var style_box = StyleBoxFlat.new()
				style_box.bg_color = Color.YELLOW
				qte_pressure_bar.add_theme_stylebox_override("fill", style_box)
				if qte_text:
					qte_text.text = prompt_text + " - GET READY... (" + str(int(progress * 100)) + "%)"
			else:
				# Red early zone (0-60%) - BAD timing, don't release
				var style_box = StyleBoxFlat.new()
				style_box.bg_color = Color.RED
				qte_pressure_bar.add_theme_stylebox_override("fill", style_box)
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
		
		if release_percentage >= 0.8 and release_percentage <= 1.0:
			result = "normal"
			print("💥 PHASE SLAM SUCCESS! Perfect release at " + str(int(release_percentage * 100)) + "%!")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/parry.wav")
				sfx_player.play()
			if target_player != null and target_player.has_method("show_block_animation"):
				target_player.show_block_animation()
		else:
			print("💥 PHASE SLAM FAILED! Released at " + str(int(release_percentage * 100)) + "% (need 80-100%)")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/miss.wav")
				sfx_player.play()
	else:
		print("💥 PHASE SLAM FAILED! Never pressed or held properly!")
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()
	
	return result

func start_sniper_qte(action_name: String, prompt_text: String, _target_player = null) -> String:
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
	
	var _input_detected = false
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
			_input_detected = true
			
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

func start_sniper_box_qte(enemy_position: Vector2) -> String:
	print("🎯 Sniper Box QTE started!")
	
	qte_active = true
	_ensure_qte_container()
	
	# Load and instantiate the sniper QTE scene
	var sniper_scene = load("res://scenes/qte/QTESniperBox.tscn")
	if not sniper_scene:
		print("❌ Could not load QTESniperBox.tscn")
		return "fail"
	
	var sniper_qte = sniper_scene.instantiate()
	get_tree().current_scene.add_child(sniper_qte)
	
	# Create random target zones around enemy
	var QTESniperBox = load("res://scenes/qte/QTESniperBox.gd")
	var zones = QTESniperBox.create_random_zones(enemy_position, Vector2(80, 80), 120.0, 200.0)
	
	# Connect signal and start QTE
	var result_data = {"hit": false, "target_index": -1, "precision": 0.0}
	sniper_qte.qte_result.connect(func(hit: bool, target_index: int, precision: float):
		result_data.hit = hit
		result_data.target_index = target_index
		result_data.precision = precision
	)
	
	sniper_qte.start_qte(zones, enemy_position)
	
	# Wait for QTE to complete
	await sniper_qte.qte_result
	
	qte_active = false
	
	# Return result based on hit success and precision
	if result_data.hit:
		if result_data.precision >= 0.8:
			return "crit"
		else:
			return "normal"
	else:
		return "fail"

func start_rapid_press_qte(prompt_text: String) -> int:
	print("🌙 Rapid Press QTE started - mash Z for 1 second!")
	
	qte_active = true
	_ensure_qte_container()
	
	var hit_count = 0
	var max_hits = 10
	var duration = 1000  # 1 second in milliseconds
	var start_time = Time.get_ticks_msec()
	
	# Show QTE UI
	show_qte("press", prompt_text, duration)
	
	# Hide circle for rapid press
	if qte_circle:
		qte_circle.visible = false
	
	while Time.get_ticks_msec() - start_time < duration and hit_count < max_hits:
		var elapsed_time = Time.get_ticks_msec() - start_time
		var time_left = duration - elapsed_time
		
		# Update text with hit count and time remaining
		if qte_text:
			var time_left_float = float(time_left) / 1000.0
			qte_text.text = prompt_text + "\nHits: " + str(hit_count) + "/" + str(max_hits) + " | Time: " + str("%.1f" % time_left_float) + "s"
		
		# Check for Z press - no cooldown, spam encouraged!
		if Input.is_action_just_pressed("confirm attack"):
			hit_count += 1
			print("🌙 Hit " + str(hit_count) + "/" + str(max_hits) + "!")
		
		await get_tree().process_frame
	
	qte_active = false
	hide_qte()
	
	print("🌙 Rapid Press QTE complete! Final hits: " + str(hit_count) + "/" + str(max_hits))
	return hit_count

func start_basic_attack_qte(action_name: String, window_ms: int, target_player = null) -> String:
	print("⚔️ Basic Attack QTE started - using new widget system!")
	print("⚔️ QTE Widget reference: ", qte_widget)
	print("⚔️ QTE Container reference: ", qte_container)
	
	qte_active = true
	_ensure_qte_container()
	
	if qte_widget == null:
		print("❌ QTEWidget not found! Falling back to old system")
		return await start_legacy_basic_qte(action_name, window_ms, target_player)
	
	# Start the widget QTE
	qte_widget.start_qte("basic", "Z")
	
	var start_time := Time.get_ticks_msec()
	var end_time := start_time + window_ms
	var input_detected := false
	var input_time := 0
	
	print("⚔️ QTE Window: " + str(window_ms) + "ms (from " + str(start_time) + " to " + str(end_time) + ")")
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	while Time.get_ticks_msec() < end_time:
		var current_time := Time.get_ticks_msec()
		if current_time == 0 or end_time == 0:
			print("❌ Invalid time values: current=", current_time, " end=", end_time)
			break
		var time_left := int(end_time) - int(current_time)
		var progress := 0.0
		if window_ms > 0:
			progress = 1.0 - (float(time_left) / float(window_ms))
		progress = clamp(progress, 0.0, 1.0)
		
		# Update widget progress (with null check)
		if qte_widget != null and qte_widget.is_inside_tree():
			qte_widget.update_progress(progress)
		
		# Debug timing every 100ms
		if (current_time - start_time) % 100 < 16:  # Roughly every 100ms
			print("⚔️ QTE Progress: ", progress, " Time left: ", time_left, "ms")
		
		if Input.is_action_just_pressed(action_name):
			input_detected = true
			input_time = Time.get_ticks_msec() - start_time
			print("⚔️ Input detected at: ", input_time, "ms")
			break
		
		await get_tree().process_frame
	
	print("⚔️ QTE Loop ended. Input detected: ", input_detected)
	
	# Determine result
	var result := "fail"
	if input_detected:
		var timing_percentage := float(input_time) / float(window_ms)
		if timing_percentage < 0.4:
			result = "crit"
			print("✨ PERFECT TIMING! CRITICAL!")
			qte_widget.show_success()
			_safe_audio_call("play_qte_success")
			ScreenShake.shake(5.0, 0.4)
			if sfx_player and action_name == "confirm attack":
				var current_actor = get_node_or_null("/root/BattleScene/TurnManager").current_actor
				if current_actor and current_actor.name == "Player1":
					sfx_player.stream = preload("res://assets/sfx/parry.wav")
				elif current_actor and current_actor.name == "Player2":
					sfx_player.stream = preload("res://assets/sfx/gun2.wav")
				sfx_player.play()
		elif timing_percentage < 0.7:
			result = "normal"
			print("✅ GOOD TIMING! SUCCESS!")
			qte_widget.show_success()
			_safe_audio_call("play_qte_success")
			if sfx_player and action_name == "confirm attack":
				var current_actor = get_node_or_null("/root/BattleScene/TurnManager").current_actor
				if current_actor and current_actor.name == "Player1":
					sfx_player.stream = preload("res://assets/sfx/attack.wav")
				elif current_actor and current_actor.name == "Player2":
					sfx_player.stream = preload("res://assets/sfx/gun1.wav")
				sfx_player.play()
		else:
			result = "fail"
			print("⚠️ TOO LATE! WEAK HIT!")
			qte_widget.show_failure()
			_safe_audio_call("play_qte_fail")
			if sfx_player and action_name == "confirm attack":
				sfx_player.stream = preload("res://assets/sfx/miss.wav")
				sfx_player.play()
	else:
		# No input detected - timeout fail
		qte_widget.show_failure()
		_safe_audio_call("play_qte_fail")
	
	# Wait for widget animation to complete
	await get_tree().create_timer(0.5).timeout
	
	qte_active = false
	print("[QTE] Basic attack QTE completed with result: " + result)
	return result

func start_legacy_basic_qte(action_name: String, window_ms: int, target_player) -> String:
	# Fallback to old system if widget not available
	print("⚔️ Using legacy QTE system for basic attack")
	# ... old QTE logic would go here if needed
	return "normal"

# Safe audio helper function - won't crash if AudioManager not available
func _safe_audio_call(method_name: String) -> void:
	# Try to find AudioManager as autoload first
	var audio_manager = get_node_or_null("/root/AudioManager")
	if not audio_manager:
		# Try to find it in the scene
		audio_manager = get_node_or_null("/root/BattleScene/AudioManager")
	
	if audio_manager and audio_manager.has_method(method_name):
		audio_manager.call(method_name)
	else:
		print("[QTE] AudioManager." + method_name + "() - stub (AudioManager not found)")
