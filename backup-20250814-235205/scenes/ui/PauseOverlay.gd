extends Control

@onready var title_label := $VBoxContainer/Title
@onready var resume_button := $VBoxContainer/ButtonContainer/ResumeButton
@onready var quit_button := $VBoxContainer/ButtonContainer/QuitButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons (with connection guards to prevent duplicates)
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
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

func _on_resume_pressed():
	print("PAUSE→ Resume pressed")
	hide_pause()

func _on_quit_pressed():
	print("PAUSE→ Quit pressed")
	get_tree().quit()
