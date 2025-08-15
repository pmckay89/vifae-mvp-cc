extends Node

# Centralized audio management with safe stubs
# All functions are safe to call even if assets/buses are missing

@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	# Set up audio players
	add_child(sfx_player)
	add_child(bgm_player)
	
	# Configure players with safe defaults
	sfx_player.bus = "Master"  # Safe fallback
	bgm_player.bus = "Master"  # Safe fallback
	
	print("[AudioManager] Initialized with stub functions")

# UI Sound Functions
func play_ui_move() -> void:
	print("[AudioManager] UI Move sound triggered")
	_play_safe_sfx("ui_move")

func play_ui_confirm() -> void:
	print("[AudioManager] UI Confirm sound triggered")
	_play_safe_sfx("ui_confirm")

# QTE Sound Functions  
func play_qte_success() -> void:
	print("[AudioManager] QTE Success sound triggered")
	_play_safe_sfx("qte_success")

func play_qte_fail() -> void:
	print("[AudioManager] QTE Fail sound triggered")
	_play_safe_sfx("qte_fail")

# Combat Sound Functions
func play_hit(kind: String = "normal") -> void:
	print("[AudioManager] Hit sound triggered - kind: " + kind)
	_play_safe_sfx("hit_" + kind)

# BGM Functions
func bgm_fade_to(track: String, duration: float = 0.4) -> void:
	print("[AudioManager] BGM fade to: " + track + " (duration: " + str(duration) + "s)")
	_fade_bgm_safe(track, duration)

# Safe helper functions that won't crash
func _play_safe_sfx(sound_id: String) -> void:
	# Check if SFX bus exists
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index == -1:
		print("[AudioManager] SFX bus not found, using Master bus")
		sfx_player.bus = "Master"
	else:
		sfx_player.bus = "SFX"
	
	# Try to load asset (placeholder paths)
	var asset_path = "res://assets/sfx/" + sound_id + ".wav"
	if ResourceLoader.exists(asset_path):
		var stream = load(asset_path)
		if stream:
			sfx_player.stream = stream
			sfx_player.play()
			print("[AudioManager] Played: " + asset_path)
		else:
			print("[AudioManager] Failed to load: " + asset_path)
	else:
		print("[AudioManager] Asset not found: " + asset_path + " (stub)")

func _fade_bgm_safe(track: String, duration: float) -> void:
	# Check if BGM bus exists
	var bgm_bus_index = AudioServer.get_bus_index("BGM")
	if bgm_bus_index == -1:
		print("[AudioManager] BGM bus not found, using Master bus")
		bgm_player.bus = "Master"
	else:
		bgm_player.bus = "BGM"
	
	# Try to load BGM asset
	var asset_path = "res://assets/music/" + track + ".ogg"
	if ResourceLoader.exists(asset_path):
		var stream = load(asset_path)
		if stream:
			# Fade out current, fade in new
			if bgm_player.playing:
				var tween = create_tween()
				tween.tween_property(bgm_player, "volume_db", -60, duration / 2)
				await tween.finished
			
			bgm_player.stream = stream
			bgm_player.volume_db = -60
			bgm_player.play()
			
			var fade_in_tween = create_tween()
			fade_in_tween.tween_property(bgm_player, "volume_db", -6, duration / 2)
			print("[AudioManager] BGM faded to: " + asset_path)
		else:
			print("[AudioManager] Failed to load BGM: " + asset_path)
	else:
		print("[AudioManager] BGM asset not found: " + asset_path + " (stub)")

# Utility functions
func stop_all_sfx() -> void:
	print("[AudioManager] Stopping all SFX")
	if sfx_player.playing:
		sfx_player.stop()

func stop_bgm() -> void:
	print("[AudioManager] Stopping BGM")
	if bgm_player.playing:
		bgm_player.stop()

func set_master_volume(volume_db: float) -> void:
	print("[AudioManager] Setting master volume: " + str(volume_db) + "db")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)