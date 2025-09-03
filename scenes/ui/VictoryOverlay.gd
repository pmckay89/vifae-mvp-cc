extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var subtitle_label := $Panel/VBoxContainer/Subtitle
@onready var map_button := $Panel/VBoxContainer/ButtonContainer/MapButton
@onready var quit_button := $Panel/VBoxContainer/ButtonContainer/QuitButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons
	if map_button and not map_button.pressed.is_connected(_on_map_pressed):
		map_button.pressed.connect(_on_map_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func show_victory():
	print("VICTORY→ Showing victory overlay")
	
	# Make visible and fade in
	visible = true
	if map_button:
		map_button.grab_focus()  # Focus on map by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_map_pressed():
	print("VICTORY→ Explore Map pressed")
	
	# Get reference to MapOverlay and show it
	var map_overlay = get_node_or_null("/root/BattleScene/UILayer/MapOverlay")
	if map_overlay and map_overlay.has_method("show_map"):
		# Hide victory overlay first
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished
		visible = false
		
		# Show map overlay
		map_overlay.show_map()
	else:
		print("ERROR→ MapOverlay not found!")

func _on_quit_pressed():
	print("VICTORY→ Quit pressed")
	get_tree().quit()