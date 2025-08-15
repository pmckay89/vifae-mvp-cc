extends Node2D

signal qte_result(hit: bool, target_index: int, precision: float)

# Tweakable exported variables
@export var crosshair_speed: float = 300.0
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
var crosshair: ColorRect
var hits_completed: Array[bool] = []  # Track which boxes have been hit
var countdown_label: Label

func _ready():
	# Create crosshair visual
	crosshair = ColorRect.new()
	crosshair.size = Vector2(20, 20)
	crosshair.color = Color.WHITE
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.pivot_offset = crosshair.size / 2
	add_child(crosshair)
	
	# Create crosshair cross pattern
	var h_line = ColorRect.new()
	h_line.size = Vector2(20, 2)
	h_line.color = Color.BLACK
	h_line.position = Vector2(0, 9)
	crosshair.add_child(h_line)
	
	var v_line = ColorRect.new()
	v_line.size = Vector2(2, 20)
	v_line.color = Color.BLACK
	v_line.position = Vector2(9, 0)
	crosshair.add_child(v_line)
	
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

func _draw():
	if qte_active:
		# Draw target zones with outlines only
		for i in range(target_zones.size()):
			var zone = target_zones[i]
			var border_width = 3
			var zone_color = Color.GREEN if hits_completed[i] else Color.RED
			
			# Draw zone outline
			draw_rect(Rect2(zone.position, Vector2(zone.size.x, border_width)), zone_color)  # Top
			draw_rect(Rect2(zone.position, Vector2(border_width, zone.size.y)), zone_color)  # Left
			draw_rect(Rect2(zone.position + Vector2(0, zone.size.y - border_width), Vector2(zone.size.x, border_width)), zone_color)  # Bottom
			draw_rect(Rect2(zone.position + Vector2(zone.size.x - border_width, 0), Vector2(border_width, zone.size.y)), zone_color)  # Right
			
			# Draw zone number and status
			var font = ThemeDB.fallback_font
			var font_size = 24
			var text = str(i + 1) + ("✓" if hits_completed[i] else "")
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = zone.get_center() - text_size / 2
			var text_color = Color.WHITE if hits_completed[i] else Color.WHITE
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

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
	
	# Show countdown timer
	if countdown_label:
		countdown_label.visible = true
	
	# Trigger redraw to show target zones
	queue_redraw()
	
	print("🎯 Scatter Shot QTE started - Hit all 3 boxes! Move with WASD, fire with Z!")

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

func _input(event: InputEvent) -> void:
	if not qte_active:
		return
		
	if event.is_action_pressed("confirm attack"):
		_handle_fire()

func _handle_fire() -> void:
	# Check if crosshair is inside any target zone
	for i in range(target_zones.size()):
		if hits_completed[i]:
			continue  # Skip already completed zones
			
		var zone = target_zones[i]
		if zone.has_point(crosshair_position):
			# Mark this zone as completed
			hits_completed[i] = true
			print("🎯 HIT! Target " + str(i + 1) + " completed!")
			
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
				# Continue QTE, update visual
				queue_redraw()
			return
	
	# No valid hit detected
	print("💨 MISS! Shot fired outside target zones")
	# Don't end QTE on miss, just continue

func _update_crosshair_position() -> void:
	if crosshair:
		crosshair.global_position = crosshair_position - crosshair.size / 2

func _end_qte(hit: bool, target_index: int, precision: float) -> void:
	qte_active = false
	
	# Emit result signal
	qte_result.emit(hit, target_index, precision)
	
	# Clean up and remove from scene
	queue_free()

# Helper function to create random target zones around a position without overlap
static func create_random_zones(center_pos: Vector2, zone_size: Vector2 = Vector2(80, 80), min_distance: float = 120.0, max_distance: float = 200.0) -> Array[Rect2]:
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
