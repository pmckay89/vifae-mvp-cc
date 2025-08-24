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

# QTE result flash overlay
var result_flash_overlay: Sprite2D

# X prompt for parry QTEs
var x_prompt_sprite: Sprite2D

# Moonfall Slash screen fade overlay (now a Control container for spotlight effect)
var moonfall_fade_overlay: Control

func _ready() -> void:
	print("QTE→ DEBUG: QTEManager _ready() called")
	# Only try to set up QTE if we're actually in the battle scene
	var current_scene = get_tree().current_scene
	print("QTE→ DEBUG: Current scene: ", current_scene.name if current_scene else "null")
	if current_scene and current_scene.name == "BattleScene":
		print("QTE→ DEBUG: Setting up QTE for BattleScene")
		_ensure_qte_container()
		_setup_result_flash_overlay()
		_setup_x_prompt()
		_setup_moonfall_fade_overlay()
		
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
		# Try to set up later when we detect we're in battle
		print("QTE→ DEBUG: Not in BattleScene, will setup later")
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
			# Start cinematic fade BEFORE the QTE
			print("🌙 Moonfall Slash selected - beginning cinematic sequence...")
			await _start_moonfall_fade_buildup()
			
			# Now start the rapid-press QTE
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
	print("🔧 start_qte called with action_name:", action_name, "prompt:", prompt_text)
	
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
	
	# Check for Multishot QTE FIRST for testing
	if action_name == "multishot":
		print("🔧 DEBUG: Multishot QTE detected, calling start_multishot_qte")
		return await start_multishot_qte(prompt_text, target_player)
	
	# Check for Mirror Strike QTE
	if action_name == "mirror_strike":
		return await start_mirror_strike_qte(prompt_text, target_player)

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
	
	# Show X prompt for parry QTEs
	if action_name == "parry":
		_show_x_prompt()
	else:
		_hide_x_prompt()
	
	# Show Player2 windup pose for basic attacks
	if prompt_text == "Press Z to attack!" and target_player and target_player.name == "Player2":
		if target_player.has_method("show_attack_windup"):
			target_player.show_attack_windup()
			print("QTE→ Showing Player2 attack windup pose")
	
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
			
			# Scale X prompt with the ring for parry QTEs
			if x_prompt_sprite and x_prompt_sprite.visible:
				var x_scale = 0.02 + (fill_progress * 0.18)  # Same scaling as ring
				x_prompt_sprite.scale = Vector2(x_scale, x_scale)

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
				# ScreenShake.shake(5.0, 0.4)  # Add screen shake for crits
				# Attack sounds now handled by TurnManager
			# Good timing: close to perfect or slightly after (65-75% and 85-95%)
			elif (timing_percentage >= 0.65 and timing_percentage < 0.75) or (timing_percentage > 0.85 and timing_percentage <= 0.95):
				result = "normal"
				print("✅ GOOD RING TIMING! SUCCESS!")
				_safe_audio_call("play_qte_success")
				# Attack sounds now handled by TurnManager
			# Poor timing: too early or too late (0-65% or 95-100%)
			else:
				result = "fail"
				print("⚠️ POOR RING TIMING! WEAK HIT!")
				_safe_audio_call("play_qte_fail")
				# Attack sounds now handled by TurnManager
	else:
		# No input detected - timeout fail
		_safe_audio_call("play_qte_fail")

	qte_active = false
	print("[QTE] cleanup done")
	hide_qte()
	
	# Hide Player2 windup pose for basic attacks
	if prompt_text == "Press Z to attack!" and target_player and target_player.name == "Player2":
		if target_player.has_method("hide_attack_windup"):
			target_player.hide_attack_windup()
			print("QTE→ Hiding Player2 attack windup pose")
	
	# Show result flash for attack QTEs
	if action_name == "confirm attack":
		show_result_flash(result)
	
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
	
	# Hide X prompt when QTE ends
	_hide_x_prompt()

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
	print("💥 Phase Slam QTE started - enhanced hold and release!")
	
	# Show enemy attack animation IMMEDIATELY before QTE
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("attack_animation") and target_player:
		enemy.attack_animation(target_player, "phase_slam")
		print("💥 Enemy pose swapped BEFORE Phase Slam QTE")
	
	qte_active = true
	_ensure_qte_container()
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# Show QTE UI using pressure bar system
	show_qte("hold_release", prompt_text, 2000)  # 2 second total time limit
	
	var total_time_limit = 2000  # 2 seconds max to complete QTE
	var qte_start_time = Time.get_ticks_msec()
	var initial_hold_time = 500  # 0.5 seconds before they can start holding
	var fill_duration = 900  # 0.9 seconds to fill once holding starts
	var is_holding = false
	var release_detected = false
	var release_time = 0
	var hold_start_time = 0
	
	# Phase 1: Simple countdown
	if qte_text:
		qte_text.text = "PHASE SLAM INCOMING..."
	
	while Time.get_ticks_msec() - qte_start_time < initial_hold_time:
		var elapsed = Time.get_ticks_msec() - qte_start_time
		
		# Simple countdown text
		if qte_text:
			var time_left = (initial_hold_time - elapsed) / 1000.0
			qte_text.text = "GET READY... " + str("%.1f" % time_left)
		
		await get_tree().process_frame
	
	# Phase 2: Clear hold prompt
	if qte_text:
		qte_text.text = "HOLD X!"
	
	# Wait for initial press with time limit
	while not is_holding and Time.get_ticks_msec() - qte_start_time < total_time_limit:
		if Input.is_action_just_pressed(action_name):
			is_holding = true
			hold_start_time = Time.get_ticks_msec()
			print("💥 Started holding X - pressure building!")
			
			# Play hold start sound
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/incoming.wav")
				sfx_player.play()
			break
		await get_tree().process_frame
	
	# Check if they failed to start holding in time
	if not is_holding:
		print("💥 PHASE SLAM FAILED! Didn't start holding in time!")
		qte_active = false
		hide_qte()
		if sfx_player:
			sfx_player.stream = preload("res://assets/sfx/miss.wav")
			sfx_player.play()
		return "fail"
	
	# Phase 3: Filling phase with enhanced visuals
	while Time.get_ticks_msec() - hold_start_time < fill_duration and Time.get_ticks_msec() - qte_start_time < total_time_limit:
		var elapsed = Time.get_ticks_msec() - hold_start_time
		var progress = float(elapsed) / float(fill_duration)
		
		# Update pressure bar
		if qte_pressure_bar:
			qte_pressure_bar.value = progress * 100
			
			# Simple color zones - no flashing
			if progress >= 0.8:
				# Release zone (80-100%) - green
				var style_box = StyleBoxFlat.new()
				style_box.bg_color = Color.GREEN
				qte_pressure_bar.add_theme_stylebox_override("fill", style_box)
				if qte_text:
					qte_text.text = "RELEASE NOW!"
			else:
				# Build zone (0-80%) - blue
				var style_box = StyleBoxFlat.new()
				style_box.bg_color = Color.BLUE
				qte_pressure_bar.add_theme_stylebox_override("fill", style_box)
				if qte_text:
					qte_text.text = "HOLD... (" + str(int(progress * 100)) + "%)"
		
		# Check if they released
		if Input.is_action_just_released(action_name):
			release_detected = true
			release_time = Time.get_ticks_msec() - hold_start_time
			break
		
		# Check if they stopped holding without releasing
		if not Input.is_action_pressed(action_name):
			print("💥 Stopped holding X without proper release!")
			break
			
		await get_tree().process_frame
	
	# Handle time limit exceeded while holding
	if not release_detected and Input.is_action_pressed(action_name) and Time.get_ticks_msec() - qte_start_time >= total_time_limit:
		print("💥 Time limit exceeded while holding!")
		release_detected = false
	
	# If they held to the end without releasing, force release
	if not release_detected and Time.get_ticks_msec() - hold_start_time >= fill_duration:
		release_time = fill_duration
		release_detected = true
		print("💥 Held to maximum - forced release!")
	
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
		elif release_percentage >= 0.8 and release_percentage < 0.9:
			result = "normal"
			print("💥 PHASE SLAM SUCCESS! Good release at " + str(int(release_percentage * 100)) + "%!")
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
		print("💥 PHASE SLAM FAILED! Never held properly or timed out!")
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
	
	# Create crosshair (moving bullet)
	var crosshair = Sprite2D.new()
	crosshair.texture = load("res://assets/objects/BulletR.png")
	crosshair.position = Vector2(50, screen_center.y)  # Start from left side
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
			var crosshair_center_x = crosshair.position.x  # Sprite2D position is already centered
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
	
	# Sound effects now handled by TurnManager
	
	# Show result flash for sniper QTE
	show_result_flash(hit_result)
	
	return hit_result

# Multishot QTE - 4 projectiles flying toward player simultaneously
func start_multishot_qte(prompt_text: String, target_player) -> String:
	print("🎯 Multishot QTE started - parry incoming projectiles!")
	
	# Show enemy attack animation IMMEDIATELY before QTE
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	if enemy and enemy.has_method("attack_animation") and target_player:
		enemy.attack_animation(target_player, "multishot")
		print("🎯 Enemy multishot animation started")
	
	qte_active = true
	_ensure_qte_container()
	
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	
	# Show QTE UI using same method as big shot
	show_qte("press", "PARRY THE INCOMING BOXES!", 5000)  # 5 second window
	
	# Hide default circle - using custom elements
	if qte_circle:
		qte_circle.visible = false
	
	# Get actual character positions from scene
	var enemy_node = get_node_or_null("/root/BattleScene/Enemy")
	var enemy_pos = enemy_node.global_position if enemy_node else Vector2(900, 300)
	
	# Use target player's actual position
	var player_pos = target_player.global_position if target_player else Vector2(135, 300)
	
	# Position green line directly on the targeted character sprite
	var parry_line_x = player_pos.x + 100
	var goal_indicator = ColorRect.new()
	goal_indicator.size = Vector2(4, 80)
	goal_indicator.color = Color.GREEN
	goal_indicator.position = Vector2(parry_line_x, player_pos.y - 40)
	qte_container.add_child(goal_indicator)
	print("🎯 Goal indicator at: ", goal_indicator.position, " (player at: ", player_pos, ")")
	
	# Create 4 projectile lines - same size as big shot crosshair
	var projectiles = []
	var projectile_results = []  # Track individual results
	
	for i in 4:
		var projectile = Sprite2D.new()
		projectile.texture = load("res://assets/objects/BulletL.png")
		# Slightly stagger Y positions around target character
		var y_offset = (i - 1.5) * 15  # Spread vertically around target
		projectile.position = Vector2(enemy_pos.x, player_pos.y + y_offset)  # Aim at target character
		
		# First projectile is visible immediately, others hidden until launch
		if i == 0:
			projectile.visible = true
		else:
			projectile.visible = false
		
		qte_container.add_child(projectile)
		projectiles.append(projectile)
		projectile_results.append("pending")  # Track each projectile
		print("🎯 Projectile ", i, " created at: ", projectile.position)
	
	# Launch sequence with 0.5s intervals
	var start_time = Time.get_ticks_msec()
	var launch_interval = 500  # 0.5 seconds in ms
	var projectile_speed = 675.0  # pixels per second (50% faster than 450)
	var parry_distance = 50.0  # Distance from player for parry window
	var launched_projectiles = []
	
	# Launch projectiles with immediate movement
	var active_projectiles = []
	
	# Start async movement for each projectile as it launches
	for i in 4:
		# Skip delay for first projectile (already visible)
		if i > 0:
			await get_tree().create_timer(launch_interval / 1000.0).timeout
			# Make projectile visible
			projectiles[i].visible = true
		
		print("🎯 Launched projectile ", i)
		
		# Play launch sound slightly after projectile begins moving
		await get_tree().create_timer(0.1).timeout
		_play_multishot_launch_sound()
		
		# Start movement immediately for this projectile
		var proj_data = {
			"projectile": projectiles[i],
			"launch_time": Time.get_ticks_msec(),
			"index": i,
			"parried": false,
			"hit": false
		}
		active_projectiles.append(proj_data)
		
		# Start async movement for this projectile
		_start_projectile_movement(proj_data, enemy_pos, player_pos, projectile_speed, parry_distance, projectile_results, target_player, parry_line_x)
	
	# Wait for all projectiles to complete (they're moving independently)
	await get_tree().create_timer(5.0).timeout  # Max QTE time
	
	# Wait for any parry animations to complete before cleanup
	await get_tree().create_timer(0.6).timeout  # Allow time for final parry animation
	
	# Clean up
	goal_indicator.queue_free()
	qte_active = false
	hide_qte()
	
	# Count results
	var hits_taken = 0
	var parries_made = 0
	for result in projectile_results:
		if result == "hit":
			hits_taken += 1
		elif result == "parried":
			parries_made += 1
	
	print("🎯 Multishot complete! Parried: ", parries_made, "/4, Hit by: ", hits_taken, "/4")
	
	# Award resolve for perfect multishot defense (no damage taken)
	if parries_made == 4 and target_player:
		var resolve_manager = get_node_or_null("/root/ResolveManager")
		if resolve_manager and resolve_manager.has_method("set_resolve"):
			var current_resolve = resolve_manager.get_resolve(target_player.name)
			resolve_manager.set_resolve(target_player.name, current_resolve + 1)
			print("RESOLVE→ " + target_player.name + " gains +1 resolve for perfect multishot defense!")
	
	# Return result based on performance
	if parries_made == 4:
		return "perfect"
	elif parries_made >= 2:
		return "normal"
	else:
		return "fail"

# Async movement for individual projectiles
func _start_projectile_movement(proj_data: Dictionary, enemy_pos: Vector2, player_pos: Vector2, projectile_speed: float, parry_distance: float, projectile_results: Array, target_player, parry_line_x: float):
	var projectile = proj_data.projectile
	# Use the passed parry_line_x position (matches green line)
	
	# Movement loop for this single projectile
	while projectile and is_instance_valid(projectile) and not proj_data.parried and not proj_data.hit:
		var current_time = Time.get_ticks_msec()
		var elapsed = (current_time - proj_data.launch_time) / 1000.0
		
		# Move projectile toward player (right to left movement)
		var progress = elapsed * projectile_speed
		projectile.position.x = enemy_pos.x - progress  # Subtract to move left
		
		# Check if projectile is in parry window (at the green line)
		var distance_to_parry_line = projectile.position.x - parry_line_x
		var distance_to_player = projectile.position.x - player_pos.x
		
		if abs(distance_to_parry_line) <= 50:  # 50px tolerance around green line (more generous)
			# In parry window - check for input
			if Input.is_action_just_pressed("parry"):
				proj_data.parried = true
				projectile_results[proj_data.index] = "parried"
				print("🎯 Projectile ", proj_data.index, " PARRIED!")
				
				# Play random parry sound
				_play_random_multishot_parry_sound()
				
				# Angle projectile upward off screen
				var tween = create_tween()
				tween.tween_property(projectile, "position", Vector2(projectile.position.x + 100, -50), 0.5)
				tween.tween_callback(func(): projectile.queue_free())
				return
		
		# Check if projectile hit player (passed parry window)
		if distance_to_player <= 0:
			proj_data.hit = true
			projectile_results[proj_data.index] = "hit"
			print("🎯 Projectile ", proj_data.index, " HIT PLAYER!")
			
			# Apply damage immediately
			if target_player and target_player.has_method("take_damage"):
				target_player.take_damage(15)
				print("🎯 Applied 15 damage to player")
			
			# Remove projectile
			projectile.queue_free()
			return
		
		await get_tree().process_frame

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
	print("🌙 Moonfall Slash QTE started - mash Z to summon moons!")
	
	qte_active = true
	_ensure_qte_container()
	
	var hit_count = 0
	var moon_count = 0
	var max_hits = 10
	var duration = 1500  # 1.5 seconds in milliseconds
	var start_time = Time.get_ticks_msec()
	
	# Show QTE UI
	show_qte("press", prompt_text, duration)
	
	# Hide circle for rapid press
	if qte_circle:
		qte_circle.visible = false
	
	# Setup Z key animation sprite
	_setup_z_key_animation()
	
	while Time.get_ticks_msec() - start_time < duration and hit_count < max_hits:
		var elapsed_time = Time.get_ticks_msec() - start_time
		var time_left = duration - elapsed_time
		
		# Update text with hit count, moon count and time remaining  
		if qte_text:
			var time_left_float = float(time_left) / 1000.0
			qte_text.text = "Hits: " + str(hit_count) + "/" + str(max_hits) + " | Moons: " + str(moon_count) + "/5 | Time: " + str("%.1f" % time_left_float) + "s"
		
		# Check for Z press - no cooldown, spam encouraged!
		if Input.is_action_just_pressed("confirm attack"):
			hit_count += 1
			print("🌙 Hit " + str(hit_count) + "/" + str(max_hits) + "!")
			
			# Every 2 hits spawns 1 moon (max 5 moons)
			if hit_count % 2 == 0 and moon_count < 5:
				moon_count += 1
				_spawn_moonfall_moon(moon_count)
				
				# Play moonfall impact sound when moon spawns
				var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
				if sfx_player:
					var moonfall_sound = load("res://assets/sfx/moonfall_impact.wav")
					if moonfall_sound:
						sfx_player.stream = moonfall_sound
						sfx_player.play()
						print("🎵 Playing moonfall impact sound for moon " + str(moon_count))
					else:
						print("⚠️ Could not load moonfall_impact.wav")
				
				print("🌙 Moon " + str(moon_count) + " summoned!")
		
		await get_tree().process_frame
	
	qte_active = false
	hide_qte()
	
	# Cleanup Z key animation
	_cleanup_z_key_animation()
	
	# End Moonfall Slash screen fade after a delay to let moons finish
	await get_tree().create_timer(1.5).timeout  # Let moons complete their flight
	_end_moonfall_fade()
	
	print("🌙 Moonfall Slash complete! " + str(hit_count) + " hits, " + str(moon_count) + " moons summoned!")
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
			# ScreenShake.shake(5.0, 0.4)
			# Attack sounds now handled by TurnManager
		elif timing_percentage < 0.7:
			result = "normal"
			print("✅ GOOD TIMING! SUCCESS!")
			qte_widget.show_success()
			_safe_audio_call("play_qte_success")
			# Attack sounds now handled by TurnManager
		else:
			result = "fail"
			print("⚠️ TOO LATE! WEAK HIT!")
			qte_widget.show_failure()
			_safe_audio_call("play_qte_fail")
			# Attack sounds now handled by TurnManager
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

# Setup QTE result flash overlay
func _setup_result_flash_overlay() -> void:
	result_flash_overlay = Sprite2D.new()
	result_flash_overlay.visible = false
	result_flash_overlay.z_index = 2000  # Above everything else
	
	# Get screen size and center the overlay
	var viewport_size = get_viewport().get_visible_rect().size
	result_flash_overlay.position = viewport_size / 2
	result_flash_overlay.scale = Vector2(0.2, 0.2)  # 20% size
	
	print("QTE→ DEBUG: Setting up flash overlay at position: ", result_flash_overlay.position)
	print("QTE→ DEBUG: Viewport size: ", viewport_size)
	
	# Add to the UI layer
	var ui_layer = get_node_or_null("/root/BattleScene/UILayer")
	if ui_layer:
		ui_layer.add_child(result_flash_overlay)
		print("QTE→ Result flash overlay setup complete - added to UILayer")
		print("QTE→ DEBUG: Flash overlay node path: ", result_flash_overlay.get_path())
	else:
		print("QTE→ ERROR: Could not find UILayer for flash overlay")

# Show QTE result flash (success or fail)
func show_result_flash(result: String) -> void:
	print("QTE→ DEBUG: show_result_flash called with result: ", result)
	
	if not result_flash_overlay:
		print("QTE→ DEBUG: Flash overlay missing, attempting to create now...")
		_setup_result_flash_overlay()
		if not result_flash_overlay:
			print("QTE→ ERROR: Could not create result flash overlay!")
			return
	
	print("QTE→ DEBUG: Flash overlay exists, current position: ", result_flash_overlay.position)
	print("QTE→ DEBUG: Flash overlay scale: ", result_flash_overlay.scale)
	
	# Choose appropriate texture based on result
	match result:
		"crit", "normal":
			result_flash_overlay.texture = preload("res://assets/ui/qte_success.png")
			print("QTE→ Showing SUCCESS flash with texture: ", result_flash_overlay.texture)
		"fail":
			result_flash_overlay.texture = preload("res://assets/ui/qte_fail.png")
			print("QTE→ Showing FAIL flash with texture: ", result_flash_overlay.texture)
		_:
			print("QTE→ DEBUG: Unknown result, not showing flash: ", result)
			return  # Don't show flash for other results
	
	# Show the flash with quick fade in/out
	result_flash_overlay.visible = true
	result_flash_overlay.modulate = Color(1, 1, 1, 0)  # Start transparent
	
	print("QTE→ DEBUG: Flash overlay made visible, starting animation")
	
	# Animate flash: different timing for success vs fail
	var tween = create_tween()
	if result == "fail":
		# Fail flash: much faster to not block subsequent QTEs
		tween.tween_property(result_flash_overlay, "modulate:a", 1.0, 0.05)  # Quick fade in
		tween.tween_property(result_flash_overlay, "modulate:a", 1.0, 0.1)   # Brief hold
		tween.tween_property(result_flash_overlay, "modulate:a", 0.0, 0.1)   # Quick fade out
	else:
		# Success flash: longer celebration
		tween.tween_property(result_flash_overlay, "modulate:a", 1.0, 0.1)  # Fade in quickly
		tween.tween_property(result_flash_overlay, "modulate:a", 1.0, 0.3)  # Hold
		tween.tween_property(result_flash_overlay, "modulate:a", 0.0, 0.2)  # Fade out
	
	tween.tween_callback(func(): 
		result_flash_overlay.visible = false
		print("QTE→ DEBUG: Flash animation complete, overlay hidden")
	)

# Setup X prompt for parry QTEs
func _setup_x_prompt() -> void:
	x_prompt_sprite = Sprite2D.new()
	x_prompt_sprite.texture = preload("res://assets/ui/prompt_x.png")
	x_prompt_sprite.scale = Vector2(0.02, 0.02)  # Start small like the ring
	x_prompt_sprite.visible = false
	x_prompt_sprite.z_index = -1  # Behind ring elements
	
	# Center it in the QTE container
	if qte_container:
		var screen_center = get_viewport().get_visible_rect().size / 2
		x_prompt_sprite.position = screen_center
		qte_container.add_child(x_prompt_sprite)
		print("QTE→ X prompt setup complete")
	else:
		print("QTE→ ERROR: Could not setup X prompt - no QTE container")

func _setup_moonfall_fade_overlay() -> void:
	print("QTE→ DEBUG: _setup_moonfall_fade_overlay() called - creating simple black overlay")
	
	# Simple black overlay - characters will be duplicated above it
	moonfall_fade_overlay = Control.new()
	moonfall_fade_overlay.visible = false
	moonfall_fade_overlay.z_index = 1500  # Characters will be duplicated above this
	moonfall_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Force fullscreen size
	var viewport_size = get_viewport().get_visible_rect().size
	moonfall_fade_overlay.position = Vector2.ZERO
	moonfall_fade_overlay.size = viewport_size
	
	# Add black background
	var black_bg = ColorRect.new()
	black_bg.color = Color(0, 0, 0, 0)  # Start transparent
	black_bg.size = viewport_size
	black_bg.position = Vector2.ZERO
	moonfall_fade_overlay.add_child(black_bg)
	moonfall_fade_overlay.set_meta("black_bg", black_bg)  # Store reference
	
	print("QTE→ Created black overlay - viewport size: ", viewport_size)
	
	# Add to UILayer
	var ui_layer = get_node_or_null("/root/BattleScene/UILayer")
	if ui_layer:
		ui_layer.add_child(moonfall_fade_overlay)
		print("QTE→ Black overlay setup complete")
	else:
		print("QTE→ ERROR: Could not setup black overlay - no UILayer found")

# Show X prompt for parry QTEs
func _show_x_prompt() -> void:
	if not x_prompt_sprite:
		print("QTE→ X prompt missing, attempting to create now...")
		_setup_x_prompt()
		if not x_prompt_sprite:
			print("QTE→ ERROR: Could not create X prompt!")
			return
	
	x_prompt_sprite.visible = true
	print("QTE→ X prompt visible")

# Hide X prompt
func _hide_x_prompt() -> void:
	if x_prompt_sprite:
		x_prompt_sprite.visible = false
		print("QTE→ X prompt hidden")

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

# Mirror Strike QTE - Copy-cat sequence defense
func start_mirror_strike_qte(prompt_text: String, target_player) -> String:
	print("🪞 Mirror Strike QTE starting!")
	
	# Play phaseslam1.wav before QTE starts
	var sfx_player := get_node_or_null("/root/BattleScene/SFXPlayer")
	if sfx_player:
		sfx_player.stream = preload("res://assets/sfx/phaseslam1.wav")
		sfx_player.play()
		print("🎵 Playing phaseslam1.wav for mirror strike")
	
	qte_active = true
	_ensure_qte_container()
	
	# Generate sequence of exactly 6 random buttons
	var button_keys = ["Z", "X", "W", "A", "D", "S"]  # All available keys for mirror strike
	var sequence_length = 6  # Fixed to 6 buttons
	var target_sequence = []
	
	for i in sequence_length:
		target_sequence.append(button_keys[randi() % button_keys.size()])
	
	print("🪞 Generated sequence: ", target_sequence)
	
	# Show the sequence and start input simultaneously
	var player_sequence = []
	
	# Start demonstration in background (non-blocking)
	show_mirror_sequence(target_sequence)
	
	# Start input collection immediately (this will block until complete)
	var result = await collect_mirror_input(target_sequence, player_sequence)
	
	qte_active = false
	hide_qte()
	
	# If player failed, play laser animation twice
	if result == "fail":
		var enemy = get_node_or_null("/root/BattleScene/Enemy")
		if enemy:
			await play_laser_animation_twice(enemy)
	
	print("🪞 Mirror Strike result: ", result)
	return result

# Play laser animation twice for failed mirror strike
func play_laser_animation_twice(enemy: Node) -> void:
	print("🔫 Playing laser animation twice for failed mirror strike")
	
	var animated_sprite = enemy.get_node_or_null("Sprite2D") as AnimatedSprite2D
	if not animated_sprite:
		print("❌ Could not find enemy AnimatedSprite2D for laser animation")
		return
	
	# Play laser animation twice
	for i in 2:
		print("🔫 Playing laser animation ", i + 1, "/2")
		animated_sprite.play("laser")
		
		# Wait for animation to complete (11 frames at 10 FPS = 1.1 seconds)
		await get_tree().create_timer(1.1).timeout
		
		# Brief pause between animations
		if i == 0:  # Only pause between first and second
			await get_tree().create_timer(0.2).timeout
	
	# Return to appropriate idle animation based on HP
	if enemy.has_method("_update_idle_animation"):
		enemy._update_idle_animation()
	
	print("🔫 Laser animation sequence complete")

# Show the button sequence to the player
func show_mirror_sequence(sequence: Array) -> void:
	print("🪞 Showing sequence: ", sequence)
	
	# Create horizontal button display at screen center
	var display_container = Control.new()
	display_container.name = "MirrorSequenceDisplay"
	display_container.size = Vector2(1000, 200)  # Even bigger container for 6 buttons
	
	# Calculate true screen center position
	var screen_size = get_viewport().get_visible_rect().size
	display_container.position.x = (screen_size.x / 2) - 500  # Center horizontally
	display_container.position.y = (screen_size.y / 2) - 100  # Center vertically
	
	# Debug background removed - container is invisible now
	
	print("🪞 DEBUG: Screen size: ", screen_size)
	print("🪞 DEBUG: Container position: ", display_container.position)
	print("🪞 DEBUG: Container size: ", display_container.size)
	
	# Manual positioning with 80-pixel spacing between centers
	var button_labels = []
	var total_width = (sequence.size() - 1) * 80  # Total width of button sequence
	var start_x = (1000 - total_width) / 2  # Center the sequence in the 1000px container
	
	for i in sequence.size():
		# Create button sprite using PNG images
		var button_sprite = TextureRect.new()
		button_sprite.size = Vector2(150, 150)  # Fixed size
		
		# Position with 80-pixel spacing between centers
		button_sprite.position.x = start_x + (i * 80)  # 80 pixels between centers
		button_sprite.position.y = 25  # Center vertically in 200-pixel container
		
		# Load the static sprite for this key
		var key_name = sequence[i].to_lower()
		var static_texture = load("res://assets/ui/" + key_name + "_static.png")
		
		if static_texture:
			button_sprite.texture = static_texture
			button_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			button_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			print("🪞 Loaded button sprite: ", key_name + "_static.png")
		else:
			print("❌ Failed to load button sprite: ", key_name + "_static.png")
			# Fallback to colored rect if texture fails
			var fallback_rect = ColorRect.new()
			fallback_rect.color = Color.GRAY
			fallback_rect.size = Vector2(150, 150)  # Match button size
			button_sprite.add_child(fallback_rect)
		
		display_container.add_child(button_sprite)
		button_labels.append(button_sprite)  # Keep reference to sprite for animations
		
		print("🪞 Button ", i, " positioned at: ", button_sprite.position)
	
	print("🪞 DEBUG: Total sequence width: ", total_width)
	print("🪞 DEBUG: Start X position: ", start_x)
	
	qte_container.add_child(display_container)
	
	# Force visibility and z-index
	display_container.visible = true
	display_container.z_index = 200
	qte_container.visible = true
	qte_container.z_index = 150
	
	print("🪞 DEBUG: Display container created at position: ", display_container.global_position)
	print("🪞 DEBUG: Display container size: ", display_container.size)
	print("🪞 DEBUG: QTE container size: ", qte_container.size)
	print("🪞 DEBUG: Button count: ", button_labels.size())
	print("🪞 DEBUG: Display container visible: ", display_container.visible)
	print("🪞 DEBUG: QTE container visible: ", qte_container.visible)
	print("🪞 DEBUG: Display container z_index: ", display_container.z_index)
	print("🪞 DEBUG: QTE container parent: ", qte_container.get_parent())
	
	# Store reference for input phase immediately
	display_container.set_meta("button_labels", button_labels)
	
	# Pulse animation for each button (runs in background, doesn't block input)
	for i in sequence.size():
		var button = button_labels[i]
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
		await get_tree().create_timer(0.4).timeout  # Slight delay between pulses

# Collect player input and validate
func collect_mirror_input(target_sequence: Array, player_sequence: Array) -> String:
	print("🪞 Input phase starting - sequence length: ", target_sequence.size())
	
	# Show "REPEAT THE SEQUENCE!" prompt
	if qte_text:
		qte_text.text = "REPEAT THE SEQUENCE!"
		qte_text.visible = true
	
	var start_time = Time.get_ticks_msec()
	var timeout_ms = 7000  # 7 second timeout
	
	# Input collection loop
	while player_sequence.size() < target_sequence.size():
		var current_time = Time.get_ticks_msec()
		if current_time - start_time > timeout_ms:
			print("🪞 Timeout! Player took too long")
			await show_mirror_failure("TIMEOUT")
			return "fail"
		
		# Check for input
		var input_detected = false
		var pressed_key = ""
		
		if Input.is_action_just_pressed("confirm attack"):  # Z
			pressed_key = "Z"
			input_detected = true
		elif Input.is_action_just_pressed("parry"):  # X
			pressed_key = "X"
			input_detected = true
		elif Input.is_action_just_pressed("move up"):  # W
			pressed_key = "W"
			input_detected = true
		elif Input.is_action_just_pressed("move left"):  # A
			pressed_key = "A"
			input_detected = true
		elif Input.is_action_just_pressed("move right"):  # D
			pressed_key = "D"
			input_detected = true
		elif Input.is_action_just_pressed("move down"):  # S
			pressed_key = "S"
			input_detected = true
		
		if input_detected:
			player_sequence.append(pressed_key)
			var expected_key = target_sequence[player_sequence.size() - 1]
			
			print("🪞 Player pressed: ", pressed_key, " Expected: ", expected_key)
			
			# Show button press animation
			await show_button_press(player_sequence.size() - 1, pressed_key)
			
			# Check if this input is correct
			if pressed_key != expected_key:
				print("🪞 Wrong button! Expected ", expected_key, " got ", pressed_key)
				await show_mirror_failure("WRONG BUTTON")
				return "fail"
			
			# Update visual progress (highlight correct input)
			update_mirror_progress(player_sequence.size() - 1)
		
		await get_tree().process_frame
	
	# Success! All inputs correct
	print("🪞 Perfect sequence! Player succeeded")
	await show_mirror_success()
	return "perfect"

# Show button press animation (switch to pressed sprite briefly)
func show_button_press(button_index: int, key: String) -> void:
	var display = qte_container.get_node_or_null("MirrorSequenceDisplay")
	if not display:
		return
	
	var button_sprites = display.get_meta("button_labels", [])
	if button_index >= button_sprites.size():
		return
	
	var button_sprite = button_sprites[button_index]
	if not button_sprite is TextureRect:
		return
	
	# Load pressed texture
	var key_name = key.to_lower()
	var pressed_texture = load("res://assets/ui/" + key_name + "_press.png")
	var static_texture = load("res://assets/ui/" + key_name + "_static.png")
	
	if pressed_texture:
		# Switch to pressed texture
		button_sprite.texture = pressed_texture
		print("🪞 Button press: ", key_name + "_press.png")
		
		# Wait briefly
		await get_tree().create_timer(0.15).timeout
		
		# Switch back to static texture
		if static_texture:
			button_sprite.texture = static_texture
			print("🪞 Button release: ", key_name + "_static.png")

# Update visual progress during input
func update_mirror_progress(button_index: int) -> void:
	var display = qte_container.get_node_or_null("MirrorSequenceDisplay")
	if display:
		var button_labels = display.get_meta("button_labels", [])
		if button_index < button_labels.size():
			var button = button_labels[button_index]
			# Change color to green to show success
			button.add_theme_color_override("font_color", Color.GREEN)

# Show failure animation
func show_mirror_failure(reason: String) -> void:
	print("🪞 Showing failure: ", reason)
	
	# Make all buttons shake and fall
	var display = qte_container.get_node_or_null("MirrorSequenceDisplay")
	if display:
		var button_labels = display.get_meta("button_labels", [])
		for button in button_labels:
			# Change to red color
			button.add_theme_color_override("font_color", Color.RED)
			
			# Shake animation
			var tween = create_tween()
			tween.parallel().tween_property(button, "position", button.position + Vector2(randf_range(-10, 10), 0), 0.1)
			tween.parallel().tween_property(button, "rotation", randf_range(-0.2, 0.2), 0.1)
			tween.tween_property(button, "position", button.position + Vector2(0, 500), 1.0)  # Fall off screen
			tween.parallel().tween_property(button, "modulate", Color.TRANSPARENT, 1.0)
	
	await get_tree().create_timer(1.0).timeout
	cleanup_mirror_display()

# Show success animation
func show_mirror_success() -> void:
	print("🪞 Showing success!")
	
	# Flash all buttons green
	var display = qte_container.get_node_or_null("MirrorSequenceDisplay")
	if display:
		var button_labels = display.get_meta("button_labels", [])
		for button in button_labels:
			button.add_theme_color_override("font_color", Color.GREEN)
			var tween = create_tween()
			tween.tween_property(button, "scale", Vector2(1.3, 1.3), 0.2)
			tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2)
	
	await get_tree().create_timer(0.6).timeout
	cleanup_mirror_display()

# Clean up the mirror display
func cleanup_mirror_display() -> void:
	var display = qte_container.get_node_or_null("MirrorSequenceDisplay")
	if display:
		display.queue_free()
	
	if qte_text:
		qte_text.visible = false

# Moonfall Slash dramatic buildup - darken background only, keep characters and UI normal
func _start_moonfall_fade_buildup() -> void:
	print("🌙 Beginning Moonfall Slash cinematic buildup - darkening background only...")
	
	# Store original states for restoration
	_store_node_visibility()
	
	# Phase 1: Darken background elements (arena, etc) but NOT characters or UI
	_darken_background_elements()
	
	# Phase 2: Hide non-essential elements (like Player2) to focus on the attack
	_hide_player2_only()
	print("🌙 Background darkened, Player2 hidden, maintaining normal lighting on Player1 and Enemy...")
	
	# Phase 3: Brief pause for dramatic effect (2 seconds)
	await get_tree().create_timer(2.0).timeout
	
	print("🌙 Moonfall cinematic buildup complete - ready for QTE!")

func _end_moonfall_fade() -> void:
	print("🌙 Ending Moonfall Slash cinematic...")
	
	# Restore all original states (background brightness, Player2 visibility, etc)
	_restore_node_visibility()
	
	print("🌙 Moonfall cinematic complete - everything restored")

# Store visibility states before hiding nodes
var stored_visibility_states = {}

# Store original z-index values for characters
var original_character_z_indices = {}

# Duplicate sprites for cinematic effect
var duplicate_player1: Sprite2D
var duplicate_enemy: Sprite2D

func _store_node_visibility() -> void:
	stored_visibility_states.clear()
	
	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		return
	
	# Store visibility of main scene nodes (only for nodes that have visibility)
	for child in battle_scene.get_children():
		if child.name not in ["Player1", "Enemy", "UILayer"]:  # Keep these visible
			# Only store visibility for nodes that actually have a visible property
			if child is CanvasItem or child is Control:
				stored_visibility_states[str(child.get_path())] = child.visible

func _hide_non_essential_nodes() -> void:
	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		return
	
	# Hide everything except Player1, Enemy, and UILayer (only nodes with visibility)
	for child in battle_scene.get_children():
		if child.name not in ["Player1", "Enemy", "UILayer"]:
			# Only hide nodes that actually have a visible property
			if child is CanvasItem or child is Control:
				child.visible = false

func _restore_node_visibility() -> void:
	# Restore all stored states (visibility and modulate)
	for key in stored_visibility_states:
		if key.ends_with("_modulate"):
			# Restore modulate property
			var node_path = key.replace("_modulate", "")
			var node = get_node_or_null(node_path)
			if node and node is CanvasItem:
				node.modulate = stored_visibility_states[key]
				print("🌙 Restored modulate for: ", node.name)
		else:
			# Restore visibility
			var node = get_node_or_null(key)
			if node and (node is CanvasItem or node is Control):
				node.visible = stored_visibility_states[key]
	
	stored_visibility_states.clear()

func _darken_background_elements() -> void:
	# Darken only background elements like arena, not characters or UI
	var background = get_node_or_null("/root/BattleScene/Background")
	if background and background is CanvasItem:
		# Store original modulate using string path
		stored_visibility_states[str(background.get_path()) + "_modulate"] = background.modulate
		
		# Darken background with tween
		var tween = create_tween()
		tween.tween_property(background, "modulate", Color(0.2, 0.2, 0.2, 1.0), 1.0)  # Very dark
		await tween.finished
		print("🌙 Background darkened")
	else:
		print("🌙 WARNING: No Background node found to darken")

func _hide_player2_only() -> void:
	# Hide only Player2 to focus on Player1's attack
	var player2 = get_node_or_null("/root/BattleScene/Player2")
	if player2:
		stored_visibility_states[str(player2.get_path())] = player2.visible
		player2.visible = false
		print("🌙 Player2 hidden - focusing on Player1's attack")

func _create_bright_duplicates() -> void:
	# Create bright sprite duplicates above the dark overlay
	var ui_layer = get_node_or_null("/root/BattleScene/UILayer")
	if not ui_layer:
		print("🌙 ERROR: No UILayer for duplicates")
		return
	
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	
	print("🌙 DEBUG: Player1 type: ", player1.get_class() if player1 else "null")
	print("🌙 DEBUG: Enemy type: ", enemy.get_class() if enemy else "null")
	
	# Create Player1 duplicate
	if player1:
		print("🌙 DEBUG: Player1 position: ", player1.global_position)
		print("🌙 DEBUG: Player1 children: ", player1.get_children())
		duplicate_player1 = _create_sprite_duplicate(player1)
		if duplicate_player1:
			duplicate_player1.z_index = 1600  # Above dark overlay (1500)
			ui_layer.add_child(duplicate_player1)
			print("🌙 Player1 duplicate created at position: ", duplicate_player1.global_position, " with texture: ", duplicate_player1.texture != null)
		else:
			print("🌙 ERROR: Failed to create Player1 duplicate")
	
	# Create Enemy duplicate  
	if enemy:
		print("🌙 DEBUG: Enemy position: ", enemy.global_position)  
		print("🌙 DEBUG: Enemy children: ", enemy.get_children())
		duplicate_enemy = _create_sprite_duplicate(enemy)
		if duplicate_enemy:
			duplicate_enemy.z_index = 1600  # Above dark overlay (1500)
			ui_layer.add_child(duplicate_enemy)
			print("🌙 Enemy duplicate created at position: ", duplicate_enemy.global_position, " with texture: ", duplicate_enemy.texture != null)
		else:
			print("🌙 ERROR: Failed to create Enemy duplicate")

func _create_sprite_duplicate(original_node: Node) -> Sprite2D:
	# Create a duplicate of a sprite node
	if not original_node is CanvasItem:
		print("🌙 DEBUG: Node is not CanvasItem: ", original_node.name)
		return null
		
	var duplicate = Sprite2D.new()
	var texture = null
	
	print("🌙 DEBUG: Trying to extract texture from ", original_node.name, " (", original_node.get_class(), ")")
	
	# Try different ways to get texture
	if original_node is Sprite2D:
		texture = original_node.texture
		print("🌙 DEBUG: Sprite2D texture: ", texture != null)
	elif original_node is AnimatedSprite2D:
		texture = original_node.sprite_frames.get_frame_texture(original_node.animation, original_node.frame)
		print("🌙 DEBUG: AnimatedSprite2D texture: ", texture != null)
	elif original_node.has_method("get_texture"):
		texture = original_node.get_texture()
		print("🌙 DEBUG: get_texture() result: ", texture != null)
	elif original_node.get("texture"):
		texture = original_node.texture
		print("🌙 DEBUG: .texture property: ", texture != null)
	else:
		# Maybe it's a container with sprite children - try to find the visible sprite
		for child in original_node.get_children():
			if child is Sprite2D and child.visible and child.texture:
				texture = child.texture
				print("🌙 DEBUG: Found texture in child ", child.name, ": ", texture != null)
				break
			elif child is AnimatedSprite2D and child.visible:
				texture = child.sprite_frames.get_frame_texture(child.animation, child.frame)
				print("🌙 DEBUG: Found texture in animated child ", child.name, ": ", texture != null)
				break
		
	if texture:
		duplicate.texture = texture
		duplicate.global_position = original_node.global_position
		duplicate.scale = original_node.scale
		duplicate.modulate = Color(1.0, 1.0, 1.0, 1.0)
		print("🌙 SUCCESS: Created duplicate with texture at ", duplicate.global_position)
		return duplicate
	else:
		print("🌙 ERROR: Could not find any texture for: ", original_node.name)
		return null

func _cleanup_duplicates() -> void:
	# Remove duplicate sprites
	if duplicate_player1:
		duplicate_player1.queue_free()
		duplicate_player1 = null
		print("🌙 Player1 duplicate cleaned up")
		
	if duplicate_enemy:
		duplicate_enemy.queue_free()
		duplicate_enemy = null
		print("🌙 Enemy duplicate cleaned up")

func _spawn_moonfall_moon(moon_id: int) -> void:
	# Create moon above Player1, flying to Enemy
	var player1 = get_node_or_null("/root/BattleScene/Player1")
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	var battle_scene = get_node_or_null("/root/BattleScene")
	
	if not player1 or not enemy or not battle_scene:
		print("🌙 ERROR: Could not spawn moon - missing nodes")
		return
	
	# Load the moon script and create instance
	var moon_script = load("res://scripts/vfx/MoonfallMeteor.gd")
	if not moon_script:
		print("🌙 ERROR: Could not load MoonfallMeteor.gd")
		return
	
	var moon = AnimatedSprite2D.new()
	moon.script = moon_script
	
	# Determine moon type: moons 1-3 use slash1, moons 4-5 use slash2
	var moon_type = "slash1"
	if moon_id >= 4:
		moon_type = "slash2"
		print("🌙 Using alternate moon type for moon ", moon_id)
	
	# Position moon with much more variation above the battle area
	var spawn_x = player1.global_position.x + randf_range(-100, 100)  # Wide spawn spread
	var spawn_y = player1.global_position.y - randf_range(120, 200)  # Varied height above
	moon.global_position = Vector2(spawn_x, spawn_y)
	
	# Target the lower half of the large enemy (bigger lower range)
	var target_x = enemy.global_position.x + randf_range(-80, 80)   # Wide impact area
	var target_y = enemy.global_position.y + randf_range(50, 200)  # Extended lower range
	var target_pos = Vector2(target_x, target_y)
	
	# Add to scene with high z-index (above everything)
	moon.z_index = 1700  # Above characters and dark overlay
	battle_scene.add_child(moon)
	
	# Launch the moon with type information
	if moon.has_method("launch_to_target"):
		if moon.has_method("set_moon_type"):
			moon.set_moon_type(moon_type)
		moon.launch_to_target(target_pos, moon_id)
	
	print("🌙 Moon ", moon_id, " (", moon_type, ") spawned at: ", moon.global_position, " targeting: ", target_pos)

# Z key animation variables
var z_key_sprite: Sprite2D
var z_key_tween: Tween

func _setup_z_key_animation():
	# Create Z key sprite for animation
	z_key_sprite = Sprite2D.new()
	z_key_sprite.texture = load("res://assets/ui/z_static.png")
	z_key_sprite.z_index = 1650  # Above dark overlay, below moons
	
	# Position next to the text area (middle-left of screen)
	if qte_container:
		var screen_center = get_viewport().get_visible_rect().size / 2
		z_key_sprite.position = Vector2(screen_center.x - 150, screen_center.y + 80)  # Left of center, below text
		z_key_sprite.scale = Vector2(0.8, 0.8)  # Slightly smaller
		qte_container.add_child(z_key_sprite)
		
		# Start looping animation: static -> press -> static
		_start_z_key_loop()
		
		print("🌙 Z key animation setup complete at position: ", z_key_sprite.position)
	else:
		print("🌙 ERROR: Could not setup Z key animation - no QTE container")

func _start_z_key_loop():
	if not z_key_sprite:
		return
		
	z_key_tween = create_tween()
	z_key_tween.set_loops()  # Loop indefinitely
	
	# Animation sequence: static (0.5s) -> press (0.3s) -> static (0.2s) -> repeat
	z_key_tween.tween_callback(func(): z_key_sprite.texture = load("res://assets/ui/z_static.png"))
	z_key_tween.tween_interval(0.5)
	z_key_tween.tween_callback(func(): z_key_sprite.texture = load("res://assets/ui/z_press.png"))
	z_key_tween.tween_interval(0.3)
	z_key_tween.tween_callback(func(): z_key_sprite.texture = load("res://assets/ui/z_static.png"))
	z_key_tween.tween_interval(0.2)
	
	print("🌙 Z key animation loop started")

func _cleanup_z_key_animation():
	# Stop animation and cleanup
	if z_key_tween:
		z_key_tween.kill()
		z_key_tween = null
		
	if z_key_sprite:
		z_key_sprite.queue_free()
		z_key_sprite = null
		
	print("🌙 Z key animation cleaned up")

func _play_multishot_launch_sound():
	# Create a new AudioStreamPlayer for each launch to allow overlapping
	var launch_player = AudioStreamPlayer.new()
	var battle_scene = get_node_or_null("/root/BattleScene")
	
	if battle_scene:
		battle_scene.add_child(launch_player)
		
		var launch_sound = load("res://assets/sfx/multishot_launch.wav")
		if launch_sound:
			launch_player.stream = launch_sound
			launch_player.play()
			print("🎯 Playing multishot launch sound")
			
			# Auto-cleanup after sound finishes
			launch_player.finished.connect(func(): launch_player.queue_free())
		else:
			print("🎯 Warning: Could not load multishot_launch.wav")
			launch_player.queue_free()
	else:
		print("🎯 Warning: Could not find BattleScene for multishot launch sound")

# Play random parry sound for multishot
func _play_random_multishot_parry_sound():
	var battle_scene = get_node_or_null("/root/BattleScene")
	if battle_scene:
		var parry_player = AudioStreamPlayer.new()
		battle_scene.add_child(parry_player)
		
		# Pick random parry sound (1-4)
		var sound_number = randi() % 4 + 1  # Random number 1-4
		var sound_file = "multishot_parry" + str(sound_number) + ".wav"
		var parry_sound = load("res://assets/sfx/" + sound_file)
		
		if parry_sound:
			parry_player.stream = parry_sound
			parry_player.play()
			print("🎯 Playing random multishot parry sound: ", sound_file)
			
			# Auto-cleanup after sound finishes
			parry_player.finished.connect(func(): parry_player.queue_free())
		else:
			print("🎯 Warning: Could not load ", sound_file)
			parry_player.queue_free()
	else:
		print("🎯 Warning: Could not find BattleScene for multishot parry sound")
