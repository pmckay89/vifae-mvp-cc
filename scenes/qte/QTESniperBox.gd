extends Node2D

signal qte_result(hit: bool, target_index: int, precision: float)

# Tweakable exported variables
@export var crosshair_speed: float = 350.0
@export var resistance_strength: float = 0.8
@export var input_inertia: float = 0.15
@export var dead_zone_radius: float = 0.1
@export var success_radius: float = 20.0
@export var max_duration: float = 3.0

# Internal variables
var target_zones: Array[Rect2] = []
var crosshair_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var qte_active: bool = false
var start_time: float
var crosshair: Sprite2D
var hits_completed: Array[bool] = []  # Track which boxes have been hit
var countdown_label: Label
var hitbox_sprites: Array[Sprite2D] = []  # Visual hitbox sprites

func _ready():
	# Create crosshair visual using new PNG
	crosshair = Sprite2D.new()
	crosshair.texture = preload("res://assets/ui/crosshair_base.png")
	crosshair.scale = Vector2(0.05, 0.05)
	add_child(crosshair)
	
	# Create countdown timer label
	countdown_label = Label.new()
	countdown_label.size = Vector2(200, 50)
	countdown_label.position = Vector2(10, 10)  # Top-left corner
	countdown_label.add_theme_font_size_override("font_size", 32)
	countdown_label.add_theme_color_override("font_color", Color.YELLOW)
	countdown_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	countdown_label.add_theme_constant_override("shadow_offset_x", 2)
	countdown_label.add_theme_constant_override("shadow_offset_y", 2)
	countdown_label.text = ""
	countdown_label.visible = false
	add_child(countdown_label)
	
	# Initialize crosshair position (will be set when QTE starts)
	var viewport_size = get_viewport().get_visible_rect().size
	crosshair_position = viewport_size / 2
	_update_crosshair_position()

func _create_hitbox_sprites():
	# Clear existing sprites
	for sprite in hitbox_sprites:
		if sprite:
			sprite.queue_free()
	hitbox_sprites.clear()
	
	# Create new hitbox sprites for each zone
	for i in range(target_zones.size()):
		var zone = target_zones[i]
		var hitbox_sprite = Sprite2D.new()
		hitbox_sprite.texture = preload("res://assets/ui/hitbox.png")
		hitbox_sprite.position = zone.get_center()
		# Scale down to 0.1 for reasonable size
		hitbox_sprite.scale = Vector2(0.1, 0.1)
		hitbox_sprite.modulate = Color.WHITE  # Default color
		add_child(hitbox_sprite)
		hitbox_sprites.append(hitbox_sprite)

func _update_hitbox_colors():
	for i in range(hitbox_sprites.size()):
		if i < hits_completed.size() and hitbox_sprites[i]:
			if hits_completed[i]:
				hitbox_sprites[i].modulate = Color.GREEN
			else:
				hitbox_sprites[i].modulate = Color.WHITE

func start_qte(zones: Array[Rect2], enemy_position: Vector2 = Vector2.ZERO) -> void:
	target_zones = zones.duplicate()
	qte_active = true
	start_time = Time.get_ticks_msec()
	
	# Initialize hit tracking for all zones
	hits_completed = []
	for i in range(target_zones.size()):
		hits_completed.append(false)
	
	# Position crosshair near enemy (with some offset)
	if enemy_position != Vector2.ZERO:
		var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		crosshair_position = enemy_position + offset
	else:
		# Fallback to screen center
		var viewport_size = get_viewport().get_visible_rect().size
		crosshair_position = viewport_size / 2
	
	velocity = Vector2.ZERO
	_update_crosshair_position()
	
	# Make sure we're visible and on top
	visible = true
	z_index = 1000
	
	# Create hitbox sprites
	_create_hitbox_sprites()
	
	# Show countdown timer
	if countdown_label:
		countdown_label.visible = true
	
	print("🎯 Scatter Shot QTE started - Guide reticle through all 3 boxes!")

func _process(delta: float) -> void:
	if not qte_active:
		return
	
	# Update countdown timer
	var current_time = Time.get_ticks_msec()
	var elapsed_time = (current_time - start_time) / 1000.0
	var time_remaining = max_duration - elapsed_time
	
	if countdown_label:
		countdown_label.text = "Time: " + str(int(ceil(time_remaining)))
	
	# Check timeout
	if time_remaining <= 0:
		_end_qte(false, -1, 0.0)
		return
	
	# Handle movement input
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move up"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("move down"):
		input_vector.y += 1.0
	
	# Apply dead zone
	if input_vector.length() < dead_zone_radius:
		input_vector = Vector2.ZERO
	else:
		input_vector = input_vector.normalized()
	
	# Apply inertia and resistance
	var target_velocity = input_vector * crosshair_speed
	velocity = velocity.lerp(target_velocity, input_inertia)
	velocity *= (1.0 - resistance_strength * delta)
	
	# Update position
	crosshair_position += velocity * delta
	
	# Constrain to viewport bounds
	var viewport_size = get_viewport().get_visible_rect().size
	crosshair_position.x = clamp(crosshair_position.x, 10, viewport_size.x - 10)
	crosshair_position.y = clamp(crosshair_position.y, 10, viewport_size.y - 10)
	
	_update_crosshair_position()
	
	# Automatic hit detection - check if crosshair is passing through any zone
	_check_automatic_hits()

func _input(event: InputEvent) -> void:
	# Input no longer needed for automatic targeting
	pass

func _check_automatic_hits() -> void:
	# Check if crosshair is inside any target zone (automatic detection)
	for i in range(target_zones.size()):
		if hits_completed[i]:
			continue  # Skip already completed zones
			
		var zone = target_zones[i]
		if zone.has_point(crosshair_position):
			# Mark this zone as completed
			hits_completed[i] = true
			print("🎯 HIT! Target " + str(i + 1) + " completed!")
			
			# Play gun sound effect
			var sfx_player = get_node_or_null("/root/BattleScene/SFXPlayer")
			if sfx_player:
				sfx_player.stream = preload("res://assets/sfx/gun1.wav")
				sfx_player.play()
			
			# Trigger subtle screen shake for this hit
			ScreenShake.shake(2.0, 0.2)
			
			# Check if all zones are completed
			var all_completed = true
			for completed in hits_completed:
				if not completed:
					all_completed = false
					break
			
			if all_completed:
				print("✅ ALL TARGETS HIT! Success!")
				_end_qte(true, -1, 1.0)  # Success with all targets
			else:
				# Continue QTE, update hitbox colors
				_update_hitbox_colors()
			return

func _update_crosshair_position() -> void:
	if crosshair:
		crosshair.global_position = crosshair_position

func _end_qte(hit: bool, target_index: int, precision: float) -> void:
	qte_active = false
	
	# Emit result signal
	qte_result.emit(hit, target_index, precision)
	
	# Clean up and remove from scene
	queue_free()

# Helper function to create random target zones around a position without overlap
static func create_random_zones(center_pos: Vector2, zone_size: Vector2 = Vector2(80, 80), min_distance: float = 80.0, max_distance: float = 180.0) -> Array[Rect2]:
	var zones: Array[Rect2] = []
	var safety_margin = 20.0  # Extra space between zones
	var max_attempts = 50  # Prevent infinite loops
	
	# Create 3 zones positioned randomly around the center without overlap
	for i in range(3):
		var attempts = 0
		var valid_position = false
		var new_zone: Rect2
		
		while not valid_position and attempts < max_attempts:
			var angle = randf() * TAU  # Random angle (0 to 2π)
			var distance = randf_range(min_distance, max_distance)
			var offset = Vector2(cos(angle), sin(angle)) * distance
			var zone_pos = center_pos + offset - zone_size / 2
			new_zone = Rect2(zone_pos, zone_size)
			
			# Check if this zone overlaps with existing zones
			valid_position = true
			for existing_zone in zones:
				var expanded_existing = Rect2(
					existing_zone.position - Vector2(safety_margin, safety_margin),
					existing_zone.size + Vector2(safety_margin * 2, safety_margin * 2)
				)
				if expanded_existing.intersects(new_zone):
					valid_position = false
					break
			
			attempts += 1
		
		if valid_position:
			zones.append(new_zone)
		else:
			# Fallback: place at fixed positions if random placement fails
			var fallback_angle = (i * 120.0) * PI / 180.0  # 120 degrees apart
			var fallback_offset = Vector2(cos(fallback_angle), sin(fallback_angle)) * min_distance
			var fallback_pos = center_pos + fallback_offset - zone_size / 2
			zones.append(Rect2(fallback_pos, zone_size))
	
	return zones
