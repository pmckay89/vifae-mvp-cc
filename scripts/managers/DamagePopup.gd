extends Node2D

# Hardcoded constants
const RISE_DISTANCE := 36.0
const RISE_TIME := 0.55
const FADE_TIME := 0.50
const SPAWN_SCALE := 0.80
const POP_SCALE := 1.15
const CRIT_POP_SCALE := 1.35
const DRIFT_RANGE_PX := 12.0
const Y_NUDGE_STEP_PX := 4.0
const CRIT_SHAKE_PX := 2.0

const COL_DAMAGE := Color(1, 1, 1, 1.0)
const COL_CRIT   := Color(1, 0.2, 0.2, 1.0)
const COL_HEAL   := Color(0.2, 1, 0.2, 1.0)
const COL_MISS   := Color(0.7, 0.7, 0.7, 0.6)

@onready var label: Label = $Label

func _ready():
	# Z-order: set above other UI elements
	z_index = max(z_index, 200)

func show_damage(value: int, label_type: String = "damage"):
	# Text & color mapping
	match label_type:
		"damage":
			label.text = str(value) if value > 0 else "0"
			label.modulate = COL_DAMAGE
		"crit":
			label.text = str(value) + "!"
			label.modulate = COL_CRIT
		"heal":
			label.text = "+" + str(value)
			label.modulate = COL_HEAL
		"miss":
			label.text = "MISS"
			label.modulate = COL_MISS
		_:
			label.text = str(value)
			label.modulate = COL_DAMAGE
	
	# Apply overlap control: drift + nudge
	_apply_overlap_control()
	
	# Start popup animation
	call_deferred("_start_animation", label_type)

func _apply_overlap_control():
	# Random X drift
	var drift_x = randf_range(-DRIFT_RANGE_PX, DRIFT_RANGE_PX)
	
	# Count existing active DamagePopup siblings
	var existing_active = 0
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling != self and sibling.get_script() == get_script() and sibling.is_inside_tree():
				existing_active += 1
	
	# Apply Y nudge based on existing popups
	var nudge_y = existing_active * Y_NUDGE_STEP_PX
	
	# Apply drift and nudge
	position += Vector2(drift_x, -nudge_y)

func _start_animation(label_type: String):
	# Create main tween
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple simultaneous animations
	
	# Start with spawn scale
	scale = Vector2(SPAWN_SCALE, SPAWN_SCALE)
	
	# Rise motion (cubic-out)
	tween.tween_property(self, "position", position + Vector2(0, -RISE_DISTANCE), RISE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade alpha over time (overlaps with rise)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	
	# Pop-in scale animation
	var target_pop_scale = CRIT_POP_SCALE if label_type == "crit" else POP_SCALE
	tween.tween_property(self, "scale", Vector2(target_pop_scale, target_pop_scale), 0.10)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10)
	
	# Crit micro-shake
	if label_type == "crit":
		_add_crit_shake(tween)
	
	# Cleanup when done
	tween.tween_callback(queue_free).set_delay(max(RISE_TIME, FADE_TIME))

func _add_crit_shake(tween: Tween):
	# 3-4 quick position flips for crit shake
	var shake_count = randi_range(3, 4)
	var shake_duration = 0.12 / float(shake_count)
	
	for i in range(shake_count):
		var shake_x = CRIT_SHAKE_PX if i % 2 == 0 else -CRIT_SHAKE_PX
		var delay = i * shake_duration
		tween.tween_method(_apply_shake_offset, 0.0, shake_x, shake_duration * 0.5).set_delay(delay)
		tween.tween_method(_apply_shake_offset, shake_x, 0.0, shake_duration * 0.5).set_delay(delay + shake_duration * 0.5)

func _apply_shake_offset(offset_x: float):
	# Apply horizontal shake offset while preserving Y position
	var base_pos = position
	base_pos.x += offset_x
	position = base_pos
