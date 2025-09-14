extends Control

@onready var settings_overlay = $SettingsOverlay

func _ready():
	# Title screen is now silent - music starts on OpeningScreen
	pass

func _on_start_button_pressed():
	print("Starting game...")
	# Stop menu music before entering battle
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")

func _on_load_button_pressed():
	print("Load button pressed (not implemented)")
	# Stop menu music if load was implemented
	AudioManager.stop_bgm()
	# Stub - no functionality for now

func _on_settings_button_pressed():
	print("Opening settings overlay...")
	if settings_overlay:
		settings_overlay.show_overlay()
	else:
		print("ERROR: Settings overlay not found!")

func _on_quit_button_pressed():
	print("Quitting game...")
	get_tree().quit()