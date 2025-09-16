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

	# Hide quit button - no need to quit mid-game
	if quit_button:
		quit_button.visible = false

	# Update button text to be clearer
	if map_button:
		map_button.text = "Continue"

	# Connect buttons
	if map_button and not map_button.pressed.is_connected(_on_map_pressed):
		map_button.pressed.connect(_on_map_pressed)

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
	print("VICTORY→ Continue pressed")

	# Get reference to ShopOverlay and show it directly
	var shop_overlay = get_node_or_null("/root/BattleScene/UILayer/ShopOverlay")
	if shop_overlay and shop_overlay.has_method("show_shop"):
		# Hide victory overlay first
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished
		visible = false

		# Show shop overlay directly
		shop_overlay.show_shop()
	else:
		print("ERROR→ ShopOverlay not found!")

