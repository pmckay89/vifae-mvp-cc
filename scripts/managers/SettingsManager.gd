extends Node

# Settings management singleton
# Handles saving/loading audio settings

var settings_file_path = "user://settings.cfg"
var settings = {}

# Default values
var default_settings = {
	"music_volume": 50,
	"music_muted": false,
	"sfx_volume": 80,
	"sfx_muted": false
}

func _ready():
	load_settings()
	apply_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(settings_file_path) != OK:
		print("[SettingsManager] No settings file found, using defaults")
		settings = default_settings.duplicate()
		return

	# Load each setting with fallback to default
	for key in default_settings.keys():
		settings[key] = config.get_value("audio", key, default_settings[key])

	print("[SettingsManager] Settings loaded: ", settings)

func save_settings():
	var config = ConfigFile.new()

	# Save all settings under "audio" section
	for key in settings.keys():
		config.set_value("audio", key, settings[key])

	if config.save(settings_file_path) == OK:
		print("[SettingsManager] Settings saved to ", settings_file_path)
	else:
		print("[SettingsManager] Failed to save settings")

func apply_settings():
	# Apply music volume
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index != -1:
		if settings.music_muted:
			AudioServer.set_bus_volume_db(music_bus_index, -80)
			print("[SettingsManager] Music muted")
		else:
			var music_db = linear_to_db(settings.music_volume / 100.0)
			AudioServer.set_bus_volume_db(music_bus_index, music_db)
			print("[SettingsManager] Music volume set to ", settings.music_volume, "% (", music_db, " db)")

	# Apply SFX volume
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index != -1:
		if settings.sfx_muted:
			AudioServer.set_bus_volume_db(sfx_bus_index, -80)
			print("[SettingsManager] SFX muted")
		else:
			var sfx_db = linear_to_db(settings.sfx_volume / 100.0)
			AudioServer.set_bus_volume_db(sfx_bus_index, sfx_db)
			print("[SettingsManager] SFX volume set to ", settings.sfx_volume, "% (", sfx_db, " db)")

	print("[SettingsManager] Audio settings applied")

# Public interface for UI
func set_music_volume(volume: int):
	settings.music_volume = clamp(volume, 0, 100)
	apply_settings()

func set_music_muted(muted: bool):
	settings.music_muted = muted
	apply_settings()

func set_sfx_volume(volume: int):
	settings.sfx_volume = clamp(volume, 0, 100)
	apply_settings()

func set_sfx_muted(muted: bool):
	settings.sfx_muted = muted
	apply_settings()

func get_music_volume() -> int:
	return settings.music_volume

func get_music_muted() -> bool:
	return settings.music_muted

func get_sfx_volume() -> int:
	return settings.sfx_volume

func get_sfx_muted() -> bool:
	return settings.sfx_muted