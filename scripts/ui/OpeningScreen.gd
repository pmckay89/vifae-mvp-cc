extends Control

# Audio constants
const BGM_DIR = "res://assets/music/"
const OPENING_THEME = "res://assets/sfx/TitleTheme.wav"
const NEXT_SCENE_AFTER_OPENING = "res://scenes/TitleScreen.tscn"


@onready var opening_music: AudioStreamPlayer = $OpeningMusic
@onready var blink_animation: AnimationPlayer = $BlinkAnimation

func _ready():
	print("OPENING→ Starting opening screen")
	
	# Start blink animation
	start_blink_animation()

	# Set up music fade-in
	if opening_music:
		# Load the new title theme
		opening_music.stream = load(OPENING_THEME)
		opening_music.volume_db = 12
		opening_music.play()
		print("Opening music volume BEFORE tween: ", opening_music.volume_db)
		
		var tween = create_tween()
		tween.tween_property(opening_music, "volume_db", 18, 0.6)
		await tween.finished
		print("Opening music volume AFTER tween: ", opening_music.volume_db)

func start_blink_animation():
	var prompt_label = $PromptLabel
	if prompt_label:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(prompt_label, "modulate:a", 0.0, 0.5)
		tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)

func _unhandled_input(event):
	# Check for any input (keyboard, mouse, gamepad)
	var input_detected = false
	
	if event is InputEventKey and event.pressed:
		input_detected = true
	elif event is InputEventMouseButton and event.pressed:
		input_detected = true
	elif event is InputEventJoypadButton and event.pressed:
		input_detected = true
		
	if input_detected and opening_music and opening_music.playing:
		print("OPENING→ Input detected, transitioning to battle")
		
		# Fade out music over 600ms, then change scene
		var tween = create_tween()
		tween.tween_property(opening_music, "volume_db", -60, 0.6)
		await tween.finished
		
		get_tree().change_scene_to_file(NEXT_SCENE_AFTER_OPENING)
