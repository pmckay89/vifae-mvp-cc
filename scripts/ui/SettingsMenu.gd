extends Control

# Audio Settings Menu
# Simple UI with Music/SFX volume controls

@onready var music_toggle = $"CenterContainer/VBoxContainer/MusicContainer/MusicControls/MusicToggle"
@onready var music_slider = $"CenterContainer/VBoxContainer/MusicContainer/MusicControls/MusicSlider"
@onready var music_value = $"CenterContainer/VBoxContainer/MusicContainer/MusicControls/MusicValue"

@onready var sfx_toggle = $"CenterContainer/VBoxContainer/SFXContainer/SFXControls/SFXToggle"
@onready var sfx_slider = $"CenterContainer/VBoxContainer/SFXContainer/SFXControls/SFXSlider"
@onready var sfx_value = $"CenterContainer/VBoxContainer/SFXContainer/SFXControls/SFXValue"

func _ready():
	# Wait for tree to be ready and call update after scene is fully loaded
	call_deferred("initialize_settings")
	print("[SettingsMenu] Settings menu initializing...")

func initialize_settings():
	# Double-check that all nodes exist before proceeding
	if not music_slider or not music_value or not music_toggle:
		print("[SettingsMenu] ERROR: Music controls not found!")
		return
	if not sfx_slider or not sfx_value or not sfx_toggle:
		print("[SettingsMenu] ERROR: SFX controls not found!")
		return

	update_ui_from_settings()
	print("[SettingsMenu] Settings menu initialized")

func update_ui_from_settings():
	var settings = SettingsManager

	# Null check before accessing nodes
	if not music_slider or not music_value or not music_toggle:
		print("[SettingsMenu] WARNING: Music controls not ready")
		return
	if not sfx_slider or not sfx_value or not sfx_toggle:
		print("[SettingsMenu] WARNING: SFX controls not ready")
		return

	# Update music controls
	music_slider.value = settings.get_music_volume()
	music_value.text = str(settings.get_music_volume()) + "%"

	if settings.get_music_muted():
		music_toggle.text = "🔇"
		music_slider.modulate = Color.GRAY
	else:
		music_toggle.text = "🎵"
		music_slider.modulate = Color.WHITE

	# Update SFX controls
	sfx_slider.value = settings.get_sfx_volume()
	sfx_value.text = str(settings.get_sfx_volume()) + "%"

	if settings.get_sfx_muted():
		sfx_toggle.text = "🔇"
		sfx_slider.modulate = Color.GRAY
	else:
		sfx_toggle.text = "🔫"
		sfx_slider.modulate = Color.WHITE

func _on_music_toggle_pressed():
	var current_muted = SettingsManager.get_music_muted()
	SettingsManager.set_music_muted(!current_muted)
	update_ui_from_settings()
	SettingsManager.save_settings()
	print("[SettingsMenu] Music muted: ", !current_muted)

func _on_music_slider_value_changed(value):
	SettingsManager.set_music_volume(int(value))
	music_value.text = str(int(value)) + "%"
	SettingsManager.save_settings()
	print("[SettingsMenu] Music volume: ", int(value))

func _on_sfx_toggle_pressed():
	var current_muted = SettingsManager.get_sfx_muted()
	SettingsManager.set_sfx_muted(!current_muted)
	update_ui_from_settings()
	SettingsManager.save_settings()
	print("[SettingsMenu] SFX muted: ", !current_muted)

func _on_sfx_slider_value_changed(value):
	SettingsManager.set_sfx_volume(int(value))
	sfx_value.text = str(int(value)) + "%"
	SettingsManager.save_settings()
	print("[SettingsMenu] SFX volume: ", int(value))

func _on_back_button_pressed():
	print("[SettingsMenu] Returning to main menu")
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
