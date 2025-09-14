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

	# Start menu music using AudioManager (will persist through settings)
	AudioManager.bgm_fade_to("TitleTheme", 0.6)

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
		
	if input_detected:
		print("OPENING→ Input detected, transitioning to title screen")
		# Music will continue playing through title screen
		get_tree().change_scene_to_file(NEXT_SCENE_AFTER_OPENING)
