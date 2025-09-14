extends Control

# Settings Overlay - can be used anywhere without scene transitions
# Same functionality as SettingsMenu but as overlay

@onready var music_toggle = $"CenterContainer/SettingsPanel/VBoxContainer/MusicContainer/MusicControls/MusicToggle"
@onready var music_slider = $"CenterContainer/SettingsPanel/VBoxContainer/MusicContainer/MusicControls/MusicSlider"
@onready var music_value = $"CenterContainer/SettingsPanel/VBoxContainer/MusicContainer/MusicControls/MusicValue"

@onready var sfx_toggle = $"CenterContainer/SettingsPanel/VBoxContainer/SFXContainer/SFXControls/SFXToggle"
@onready var sfx_slider = $"CenterContainer/SettingsPanel/VBoxContainer/SFXContainer/SFXControls/SFXSlider"
@onready var sfx_value = $"CenterContainer/SettingsPanel/VBoxContainer/SFXContainer/SFXControls/SFXValue"

var pause_overlay = null

func _ready():
	# Ensure proper mouse filtering for overlay behavior
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dark_bg = $DarkBackground
	if dark_bg:
		dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP

	# Wait for nodes to initialize
	call_deferred("initialize_settings")
	print("[SettingsOverlay] Settings overlay ready")

func initialize_settings():
	# Verify all nodes exist
	if not music_slider or not music_value or not music_toggle:
		print("[SettingsOverlay] ERROR: Music controls not found!")
		return
	if not sfx_slider or not sfx_value or not sfx_toggle:
		print("[SettingsOverlay] ERROR: SFX controls not found!")
		return

	update_ui_from_settings()
	print("[SettingsOverlay] Settings overlay initialized")

func show_overlay(calling_pause_overlay = null):
	pause_overlay = calling_pause_overlay
	visible = true
	# Ensure we can receive input
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Move to front of parent to ensure it's on top
	move_to_front()
	# Grab focus to ensure this overlay gets input priority
	grab_focus()
	update_ui_from_settings()
	print("[SettingsOverlay] Overlay shown")

func hide_overlay():
	visible = false
	print("[SettingsOverlay] Overlay hidden")

	# If we came from pause menu, show it again
	if pause_overlay:
		pause_overlay.show_pause_from_settings()
		pause_overlay = null

func update_ui_from_settings():
	var settings = SettingsManager

	# Null check before accessing nodes
	if not music_slider or not music_value or not music_toggle:
		print("[SettingsOverlay] WARNING: Music controls not ready")
		return
	if not sfx_slider or not sfx_value or not sfx_toggle:
		print("[SettingsOverlay] WARNING: SFX controls not ready")
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
	print("[SettingsOverlay] Music muted: ", !current_muted)

func _on_music_slider_value_changed(value):
	SettingsManager.set_music_volume(int(value))
	music_value.text = str(int(value)) + "%"
	SettingsManager.save_settings()
	print("[SettingsOverlay] Music volume: ", int(value))

func _on_sfx_toggle_pressed():
	var current_muted = SettingsManager.get_sfx_muted()
	SettingsManager.set_sfx_muted(!current_muted)
	update_ui_from_settings()
	SettingsManager.save_settings()
	print("[SettingsOverlay] SFX muted: ", !current_muted)

func _on_sfx_slider_value_changed(value):
	SettingsManager.set_sfx_volume(int(value))
	sfx_value.text = str(int(value)) + "%"
	SettingsManager.save_settings()
	print("[SettingsOverlay] SFX volume: ", int(value))

func _on_close_button_pressed():
	hide_overlay()
	print("[SettingsOverlay] Close button pressed")

# Handle ESC key to close overlay
func _unhandled_key_input(event):
	if event.pressed and event.keycode == KEY_ESCAPE:
		hide_overlay()
		get_viewport().set_input_as_handled()

# Debug mouse input
func _gui_input(event):
	if event is InputEventMouseButton:
		print("[SettingsOverlay] Mouse click received: ", event.position)

func _input(event):
	if visible and event is InputEventMouseButton:
		print("[SettingsOverlay] Input event received: ", event.position)