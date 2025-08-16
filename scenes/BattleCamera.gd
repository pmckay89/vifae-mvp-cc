extends Camera2D

var shake_timer := 0.0
var shake_intensity := 0.0
var original_position := Vector2.ZERO
var original_zoom := Vector2.ONE
var target_zoom := Vector2.ONE
var zoom_tween: Tween
var position_tween: Tween
var target_position := Vector2.ZERO

# Scene boundaries (1152x658 with larger margins to allow more pan)
const BOUNDARY_MIN_X = -550.0
const BOUNDARY_MAX_X = 550.0
const BOUNDARY_MIN_Y = -300.0
const BOUNDARY_MAX_Y = 300.0

func _ready():
	make_current()
	original_position = global_position
	original_zoom = zoom
	target_position = original_position

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		var shake_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_intensity
		global_position = target_position + shake_offset
	else:
		global_position = target_position

func shake(duration: float, intensity: float):
	shake_timer = duration
	shake_intensity = intensity

func zoom_to_target(target_node: Node2D, zoom_amount: float = 1.02, duration: float = 0.3):
	if not target_node:
		print("❌ BattleCamera: Cannot zoom to null target")
		return
	
	# Kill existing tweens
	if zoom_tween:
		zoom_tween.kill()
	if position_tween:
		position_tween.kill()
	
	# Create new tweens
	zoom_tween = create_tween()
	position_tween = create_tween()
	
	# Calculate desired shift toward defender (horizontal only)
	var desired_shift = 40.0
	var direction_to_target = (target_node.global_position - original_position).normalized()
	# Zero out Y component - only horizontal movement
	direction_to_target.y = 0
	direction_to_target = direction_to_target.normalized()
	var desired_position = original_position + (direction_to_target * desired_shift)
	
	# Clamp to boundaries (horizontal only) and calculate lost distance
	var clamped_position = Vector2(
		clamp(desired_position.x, BOUNDARY_MIN_X, BOUNDARY_MAX_X),
		original_position.y  # Keep original Y position - no vertical movement
	)
	
	# Calculate how much shift we lost due to clamping
	var lost_distance = desired_position.distance_to(clamped_position)
	
	# Convert lost distance to extra zoom (0.0002x per lost pixel, max 1.02x total)
	var compensation_zoom = lost_distance * 0.0002
	var final_zoom = min(zoom_amount + compensation_zoom, 1.02)
	
	target_position = clamped_position
	target_zoom = Vector2(final_zoom, final_zoom)
	
	print("🎥 BattleCamera: Hybrid shift toward " + target_node.name + " (zoom: " + str(final_zoom) + "x, pan: " + str(desired_shift - lost_distance) + "px, lost: " + str(lost_distance) + "px)")
	
	# Animate zoom and position simultaneously
	zoom_tween.tween_property(self, "zoom", target_zoom, duration)
	position_tween.tween_property(self, "target_position", target_position, duration)

func zoom_to_original(duration: float = 0.3):
	# Kill existing tweens
	if zoom_tween:
		zoom_tween.kill()
	if position_tween:
		position_tween.kill()
	
	# Create new tweens
	zoom_tween = create_tween()
	position_tween = create_tween()
	
	print("🎥 BattleCamera: Returning to original position and zoom")
	
	# Animate back to original
	zoom_tween.tween_property(self, "zoom", original_zoom, duration)
	position_tween.tween_property(self, "target_position", original_position, duration)
