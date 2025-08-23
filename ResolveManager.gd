extends Node

# Resolve system - secondary combat resource tied to QTE performance
var player1_resolve: int = 0
var player2_resolve: int = 0
const MAX_RESOLVE: int = 6

# UI elements
var resolve_ui_container: Control
var player1_resolve_label: Label
var player2_resolve_label: Label

func _ready():
	print("RESOLVE→ ResolveManager initialized")
	_setup_ui()

# Setup UI elements with retry mechanism
func _setup_ui():
	# Wait longer for battle scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		print("RESOLVE→ Warning: BattleScene not found, retrying...")
		# Retry after a short delay
		await get_tree().create_timer(0.1).timeout
		_try_setup_ui()
		return
	
	_try_setup_ui()

func _try_setup_ui():
	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		print("RESOLVE→ Error: BattleScene still not found")
		return
	
	var ui_layer = battle_scene.get_node_or_null("UILayer")
	if not ui_layer:
		print("RESOLVE→ Error: UILayer not found")
		return
	
	# Find the existing HPBars container
	var hp_bars = ui_layer.get_node_or_null("HPBars")
	if not hp_bars:
		print("RESOLVE→ Error: HPBars container not found")
		return
	
	# Use the existing resolve labels you created
	player1_resolve_label = hp_bars.get_node_or_null("Player1Resolve")
	player2_resolve_label = hp_bars.get_node_or_null("Player2Resolve")
	
	if not player1_resolve_label or not player2_resolve_label:
		print("RESOLVE→ Error: Resolve labels not found - P1: ", player1_resolve_label, " P2: ", player2_resolve_label)
		print("RESOLVE→ Available children in HPBars: ", hp_bars.get_children())
		return
	
	resolve_ui_container = hp_bars
	
	# Initialize the text to match scene format
	player1_resolve_label.text = "RESOLVE: 0/6"
	player2_resolve_label.text = "RESOLVE: 0/6"
	
	print("RESOLVE→ UI setup successful! Labels found and initialized.")

# Safe function to set resolve with clamping and visual feedback
func set_resolve(character_name: String, new_value: int):
	var old_value = get_resolve(character_name)
	var clamped_value = clamp(new_value, 0, MAX_RESOLVE)
	
	# Find labels dynamically every time (bypass initialization issues)
	var battle_scene = get_node_or_null("/root/BattleScene")
	if not battle_scene:
		print("RESOLVE→ ERROR: BattleScene not found")
		return
		
	var hp_bars = battle_scene.get_node_or_null("UILayer/HPBars")
	if not hp_bars:
		print("RESOLVE→ ERROR: HPBars not found")
		return
	
	var p1_label = hp_bars.get_node_or_null("Player1Resolve")
	var p2_label = hp_bars.get_node_or_null("Player2Resolve")
	
	match character_name:
		"Player1":
			player1_resolve = clamped_value
			if p1_label:
				p1_label.text = "RESOLVE: " + str(player1_resolve) + "/6"
				print("RESOLVE→ P1 updated to: ", p1_label.text)
			else:
				print("RESOLVE→ ERROR: Player1Resolve label not found in scene")
		"Player2":
			player2_resolve = clamped_value
			if p2_label:
				p2_label.text = "RESOLVE: " + str(player2_resolve) + "/6"
				print("RESOLVE→ P2 updated to: ", p2_label.text)
			else:
				print("RESOLVE→ ERROR: Player2Resolve label not found in scene")
	
	print("RESOLVE→ " + character_name + " resolve: " + str(old_value) + " → " + str(clamped_value))

# Get current resolve value
func get_resolve(character_name: String) -> int:
	match character_name:
		"Player1": return player1_resolve
		"Player2": return player2_resolve
		_: return 0

# Light shake animation for meter
func _shake_meter():
	if resolve_ui_container:
		var tween = create_tween()
		var original_pos = resolve_ui_container.position
		tween.tween_property(resolve_ui_container, "position", original_pos + Vector2(3, 0), 0.05)
		tween.tween_property(resolve_ui_container, "position", original_pos + Vector2(-3, 0), 0.05)
		tween.tween_property(resolve_ui_container, "position", original_pos, 0.05)

# Reset resolve for both characters (battle start/retry)
func reset_all_resolve():
	set_resolve("Player1", 0)
	set_resolve("Player2", 0)
	print("RESOLVE→ All resolve reset to 0")

# Debug functions for testing
func debug_increment_resolve(character_name: String):
	var current = get_resolve(character_name)
	set_resolve(character_name, current + 1)

func debug_decrement_resolve(character_name: String):
	var current = get_resolve(character_name)
	set_resolve(character_name, current - 1)
