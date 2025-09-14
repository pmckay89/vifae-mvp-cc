extends Control

@onready var title_label := $VBoxContainer/Title
@onready var resume_button := $VBoxContainer/ButtonContainer/ResumeButton
@onready var settings_button := $VBoxContainer/ButtonContainer/SettingsButton
@onready var quit_button := $VBoxContainer/ButtonContainer/QuitButton
@onready var panel := $Panel
@onready var settings_overlay := get_node("../SettingsOverlay")

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons (with connection guards to prevent duplicates)
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func show_pause():
	print("PAUSE→ Showing pause overlay")
	
	# Make visible and fade in
	visible = true
	if resume_button:
		resume_button.grab_focus()  # Focus on resume by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_pause():
	print("PAUSE→ Hiding pause overlay")

	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false

func show_pause_from_settings():
	print("PAUSE→ Returning from settings")
	# Show pause menu again (no animation needed)
	visible = true
	modulate.a = 1.0
	if resume_button:
		resume_button.grab_focus()

func _on_resume_pressed():
	print("PAUSE→ Resume pressed")
	hide_pause()
	# Let TurnManager handle ActionMenu restoration based on game state
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	if turn_manager and turn_manager.has_method("restore_ui_after_pause"):
		turn_manager.restore_ui_after_pause()

func _on_settings_pressed():
	print("PAUSE→ Settings pressed")
	if settings_overlay:
		print("PAUSE→ Found settings overlay, showing...")
		# Fully hide pause menu (no fade, immediate)
		hide_pause_immediately()
		settings_overlay.show_overlay(self)
	else:
		print("PAUSE→ Settings overlay not found!")

func hide_pause_immediately():
	print("PAUSE→ Hiding pause immediately")
	visible = false
	modulate.a = 0.0

func _on_quit_pressed():
	print("PAUSE→ Quit pressed")
	get_tree().quit()
