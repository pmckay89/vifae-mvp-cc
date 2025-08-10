extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var subtitle_label := $Panel/VBoxContainer/Subtitle
@onready var retry_button := $Panel/VBoxContainer/ButtonContainer/RetryButton
@onready var quit_button := $Panel/VBoxContainer/ButtonContainer/QuitButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons (with proper null checks)
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
	else:  # "defeat"
		title_label.text = "Game Over"
		subtitle_label.text = "Better luck next time..."
	
	# Make visible and fade in
	visible = true
	if retry_button:
		retry_button.grab_focus()  # Focus on retry by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_retry_pressed():
	print("OVERLAY→ Retry pressed")
	get_tree().reload_current_scene()

func _on_quit_pressed():
	print("OVERLAY→ Quit pressed")
	get_tree().quit()
