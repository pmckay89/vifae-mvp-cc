extends Control

@onready var settings_overlay = $SettingsOverlay
@onready var load_button = $MenuContainer/LoadButton
@onready var start_button = $MenuContainer/StartButton
@onready var settings_button = $MenuContainer/SettingsButton
@onready var quit_button = $MenuContainer/QuitButton

func _ready():
	# Title screen is now silent - music starts on OpeningScreen
	# Enable/disable Load button based on save file existence
	if SaveManager.has_save_file():
		load_button.disabled = false
		load_button.text = "Continue"
	else:
		load_button.disabled = true
		load_button.text = "Continue (No Save)"

	# Set up focus navigation for W/S keys
	setup_menu_navigation()

func setup_menu_navigation():
	# Set focus neighbors for vertical navigation
	start_button.focus_neighbor_top = quit_button.get_path()
	start_button.focus_neighbor_bottom = load_button.get_path()

	load_button.focus_neighbor_top = start_button.get_path()
	load_button.focus_neighbor_bottom = settings_button.get_path()

	settings_button.focus_neighbor_top = load_button.get_path()
	settings_button.focus_neighbor_bottom = quit_button.get_path()

	quit_button.focus_neighbor_top = settings_button.get_path()
	quit_button.focus_neighbor_bottom = start_button.get_path()

	# Give initial focus to Start button
	start_button.grab_focus()
	print("[TitleScreen] Menu navigation set up")

func _input(event):
	# Handle W/S navigation using existing input actions
	if event.is_action_pressed("move up"):
		print("[TitleScreen] Move up pressed")
		_navigate_up()
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("move down"):
		print("[TitleScreen] Move down pressed")
		_navigate_down()
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("confirm attack"):  # Z key
		print("[TitleScreen] Confirm pressed")
		_confirm_selection()
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()

func _navigate_up():
	var focused = get_viewport().gui_get_focus_owner()
	if focused == start_button:
		quit_button.grab_focus()
	elif focused == load_button:
		start_button.grab_focus()
	elif focused == settings_button:
		load_button.grab_focus()
	elif focused == quit_button:
		settings_button.grab_focus()

func _navigate_down():
	var focused = get_viewport().gui_get_focus_owner()
	if focused == start_button:
		load_button.grab_focus()
	elif focused == load_button:
		settings_button.grab_focus()
	elif focused == settings_button:
		quit_button.grab_focus()
	elif focused == quit_button:
		start_button.grab_focus()

func _confirm_selection():
	var focused = get_viewport().gui_get_focus_owner()
	if focused == start_button:
		_on_start_button_pressed()
	elif focused == load_button and not load_button.disabled:
		_on_load_button_pressed()
	elif focused == settings_button:
		_on_settings_button_pressed()
	elif focused == quit_button:
		_on_quit_button_pressed()

func _on_start_button_pressed():
	print("Starting game...")
	# Stop menu music before entering battle
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")

func _on_load_button_pressed():
	print("Loading saved game...")
	# Stop menu music before loading
	AudioManager.stop_bgm()

	# Load save data
	var save_data = SaveManager.load_game()
	if save_data.is_empty():
		print("ERROR: No save file found or save corrupted!")
		return

	# Store save data in SaveManager for application after scene loads
	SaveManager.pending_save_data = save_data

	# Load the saved scene
	var scene_to_load = save_data.get("current_scene", "BattleScene")
	get_tree().change_scene_to_file("res://scenes/" + scene_to_load + ".tscn")

func _on_settings_button_pressed():
	print("Opening settings overlay...")
	if settings_overlay:
		settings_overlay.show_overlay()
		# Connect to overlay close signal to restore focus
		if not settings_overlay.is_connected("overlay_closed", _on_settings_overlay_closed):
			settings_overlay.connect("overlay_closed", _on_settings_overlay_closed)
	else:
		print("ERROR: Settings overlay not found!")

func _on_settings_overlay_closed():
	# Restore focus to settings button when overlay closes
	settings_button.grab_focus()
	print("[TitleScreen] Focus restored after settings closed")

func _on_quit_button_pressed():
	print("Quitting game...")
	get_tree().quit()
