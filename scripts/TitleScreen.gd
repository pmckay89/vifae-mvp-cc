extends Control

func _ready():
	# Play title theme if available
	var title_audio = load("res://assets/sfx/TitleTheme.wav")
	if title_audio:
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_player.stream = title_audio
		audio_player.play()

func _on_start_button_pressed():
	print("Starting game...")
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")

func _on_load_button_pressed():
	print("Load button pressed (not implemented)")
	# Stub - no functionality for now

func _on_settings_button_pressed():
	print("Settings button pressed (not implemented)")
	# Stub - no functionality for now

func _on_quit_button_pressed():
	print("Quitting game...")
	get_tree().quit()