extends AnimatedSprite2D

# Moonfall Slash moon - animated celestial body that flies to target

var target_position: Vector2
var flight_duration: float = 1.0  # Animation duration matches flight time
var moon_id: int = 0
var moon_type: String = "slash1"  # Default to slash1

func _ready():
	# Animation frames will be set up when moon type is specified
	# Don't start animation yet - wait for launch_to_target()
	print("🌙 Moon ", moon_id, " ready - waiting for type and launch")

func _setup_animation_frames():
	# Create sprite frames for the 14-frame animation
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("meteor_flight")
	sprite_frames.set_animation_loop("meteor_flight", false)  # Play once
	sprite_frames.set_animation_speed("meteor_flight", 20.0)  # 20 fps - faster animation
	
	# Load the appropriate sprite sheet based on moon type
	var sprite_sheet_path = "res://assets/animations/moonfall " + moon_type + ".png"
	var sprite_sheet = load(sprite_sheet_path)
	if not sprite_sheet:
		print("🌙 ERROR: Could not load ", sprite_sheet_path)
		return
	
	# Different frame counts based on moon type
	var frame_count = 14 if moon_type == "slash1" else 7
	print("🌙 Loading ", frame_count, " frames for moon type: ", moon_type)
	
	# Slice the sprite sheet into frames (64x64 each)
	for i in range(frame_count):
		var frame_texture = AtlasTexture.new()
		frame_texture.atlas = sprite_sheet
		frame_texture.region = Rect2(i * 64, 0, 64, 64)
		sprite_frames.add_frame("meteor_flight", frame_texture)
	
	self.sprite_frames = sprite_frames
	print("🌙 Moon (", moon_type, ") animation frames loaded: ", sprite_frames.get_frame_count("meteor_flight"))

func launch_to_target(target_pos: Vector2, id: int = 0):
	target_position = target_pos
	moon_id = id
	
	# Set up animation frames now that moon type is known
	_setup_animation_frames()
	
	# Set scale based on moon type - slash2 moons are 3x bigger
	if moon_type == "slash2":
		scale = Vector2(3.0, 3.0)
		print("🌙 Large moon (3x scale) for type: ", moon_type)
	else:
		scale = Vector2(1.0, 1.0)
	
	# Start the moon animation
	play("meteor_flight")
	print("🌙 Moon ", moon_id, " (", moon_type, ") launched from: ", global_position, " to: ", target_position)
	
	# Start flight tween
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, flight_duration)
	
	# When flight completes, vanish
	tween.tween_callback(_on_impact)

func _on_impact():
	print("🌙 Moon ", moon_id, " impact at: ", global_position)
	
	# Apply individual damage for this moon impact
	var enemy = get_node_or_null("/root/BattleScene/Enemy")
	
	if enemy and enemy.has_method("take_damage"):
		var moon_damage = 5
		print("🌙 Moon ", moon_id, " deals ", moon_damage, " damage!")
		enemy.take_damage(moon_damage)
		
		# Show individual damage popup for this moon using direct popup creation
		_show_moon_damage_popup(enemy, moon_damage)
		
		# Add individual screen shake - bigger for the last two moons (slash2 type)
		if moon_type == "slash2":  # Moons 4-5 are the large ones
			ScreenShake.shake(6.0, 0.25)  # Big shake for large moons
			print("🌙 Large moon impact - BIG screen shake triggered")
		else:
			ScreenShake.shake(3.0, 0.15)  # Normal shake for regular moons
			print("🌙 Moon impact screen shake triggered")
	else:
		print("🌙 Warning: Could not find enemy to damage")
	
	# Vanish on contact
	queue_free()

func set_moon_type(type: String):
	moon_type = type
	print("🌙 Moon type set to: ", moon_type)

func _show_moon_damage_popup(target_node: Node, amount: int):
	if target_node == null:
		print("🌙 Cannot show damage popup on null target")
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		print("🌙 Could not load DamagePopup.tscn")
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(90, -50)
	popup.show_damage(amount)
	print("🌙 Moon damage popup created: ", amount, " damage")