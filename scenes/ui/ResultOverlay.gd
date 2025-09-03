extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var subtitle_label := $Panel/VBoxContainer/Subtitle
@onready var map_button := $Panel/VBoxContainer/ButtonContainer/MapButton
@onready var retry_button := $Panel/VBoxContainer/ButtonContainer/RetryButton
@onready var quit_button := $Panel/VBoxContainer/ButtonContainer/QuitButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons (with proper null checks)
	if map_button and not map_button.pressed.is_connected(_on_map_pressed):
		map_button.pressed.connect(_on_map_pressed)
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func show_result(mode: String):
	print("OVERLAY→ Showing result: " + mode)
	
	# Set text based on mode
	if mode == "victory":
		title_label.text = "Victory"
		subtitle_label.text = "Well done!"
		# Show map button only on victory
		if map_button:
			map_button.visible = true
	else:  # "defeat"
		title_label.text = "Game Over"
		subtitle_label.text = "Better luck next time..."
		# Hide map button on defeat
		if map_button:
			map_button.visible = false
	
	# Make visible and fade in
	visible = true
	
	# Focus on map button if victory, otherwise retry
	if mode == "victory" and map_button and map_button.visible:
		map_button.grab_focus()
	elif retry_button:
		retry_button.grab_focus()
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_map_pressed():
	print("OVERLAY→ Map pressed")
	
	# Get reference to MapOverlay and show it
	var map_overlay = get_node_or_null("/root/BattleScene/UILayer/MapOverlay")
	if map_overlay and map_overlay.has_method("show_map"):
		# Hide result overlay first
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished
		visible = false
		
		# Show map overlay
		map_overlay.show_map()
	else:
		print("ERROR→ MapOverlay not found!")

func _on_retry_pressed():
	print("OVERLAY→ Retry pressed")
	get_tree().reload_current_scene()

func _on_quit_pressed():
	print("OVERLAY→ Quit pressed")
	get_tree().quit()
