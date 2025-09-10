extends Node2D

# Hardcoded constants
const RISE_DISTANCE := 36.0
const RISE_TIME := 0.55
const FADE_TIME := 0.50
# Status effect timing - linger much longer to see colors/emojis clearly
const STATUS_RISE_TIME := 1.0
const STATUS_FADE_TIME := 4.0  # 5 seconds total display time
const SPAWN_SCALE := 0.80
const POP_SCALE := 1.15
const CRIT_POP_SCALE := 1.35
const DRIFT_RANGE_PX := 12.0
const Y_NUDGE_STEP_PX := 4.0
const STATUS_Y_NUDGE_STEP_PX := 8.0  # Slightly bigger spacing for status effects
const CRIT_SHAKE_PX := 2.0

const COL_DAMAGE := Color(1, 1, 1, 1.0)
const COL_CRIT   := Color(1, 0.2, 0.2, 1.0)
const COL_HEAL   := Color(0.2, 1, 0.2, 1.0)
const COL_MISS   := Color(0.7, 0.7, 0.7, 0.6)
const COL_POISON := Color(0.2, 0.8, 0.2, 1.0)  # Green poison color
const COL_BURN   := Color(1.0, 0.4, 0.1, 1.0)  # Orange-red burn color
const COL_BLEED  := Color(0.8, 0.1, 0.1, 1.0)  # Dark red bleed color

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
		"poison":
			label.text = str(value)
			label.modulate = COL_POISON
		"burn":
			label.text = str(value)
			label.modulate = COL_BURN
		"bleed":
			label.text = str(value)
			label.modulate = COL_BLEED
		_:
			label.text = str(value)
			label.modulate = COL_DAMAGE
	
	# Apply overlap control: drift + nudge
	_apply_overlap_control(_is_status_effect(label_type))
	
	# Start popup animation
	call_deferred("_start_animation", label_type)

func show_poison_damage(value: int):
	show_damage(value, "poison")

func show_burn_damage(value: int):
	show_damage(value, "burn")

func show_bleed_damage(value: int):
	show_damage(value, "bleed")

func show_status_effect(message: String, effect_type: String):
	# Show status application message with appropriate color/timing
	match effect_type:
		"burn":
			label.text = message
			label.modulate = COL_BURN
			call_deferred("_start_animation", "burn")
		"poison":
			label.text = message
			label.modulate = COL_POISON
			call_deferred("_start_animation", "poison")
		"bleed":
			label.text = message
			label.modulate = COL_BLEED
			call_deferred("_start_animation", "bleed")
		_:
			# Generic status effect
			label.text = message
			label.modulate = COL_DAMAGE
			call_deferred("_start_animation", "damage")
	
	# Apply overlap control for status effects
	_apply_overlap_control(true)

func _apply_overlap_control(is_status_effect: bool = false):
	# Simple drift and nudge system
	var drift_x = randf_range(-DRIFT_RANGE_PX, DRIFT_RANGE_PX)
	
	# Count existing active DamagePopup siblings
	var existing_active = 0
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling != self and sibling.get_script() == get_script() and sibling.is_inside_tree():
				existing_active += 1
	
	# Use appropriate spacing
	var nudge_step = STATUS_Y_NUDGE_STEP_PX if is_status_effect else Y_NUDGE_STEP_PX
	var nudge_y = existing_active * nudge_step
	
	# Apply drift and nudge
	position += Vector2(drift_x, -nudge_y)

func _start_animation(label_type: String):
	# Create main tween
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple simultaneous animations
	
	# Start with spawn scale
	scale = Vector2(SPAWN_SCALE, SPAWN_SCALE)
	
	# Choose timing based on effect type
	var rise_time = STATUS_RISE_TIME if _is_status_effect(label_type) else RISE_TIME
	var fade_time = STATUS_FADE_TIME if _is_status_effect(label_type) else FADE_TIME
	
	# Rise motion (cubic-out)
	tween.tween_property(self, "position", position + Vector2(0, -RISE_DISTANCE), rise_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade alpha over time (overlaps with rise)
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	
	# Pop-in scale animation
	var target_pop_scale = CRIT_POP_SCALE if label_type == "crit" else POP_SCALE
	tween.tween_property(self, "scale", Vector2(target_pop_scale, target_pop_scale), 0.10)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_delay(0.10)
	
	# Crit micro-shake
	if label_type == "crit":
		_add_crit_shake(tween)
	
	# Cleanup when done - use appropriate timing
	var cleanup_delay = max(rise_time, fade_time)
	tween.tween_callback(queue_free).set_delay(cleanup_delay)

# Helper function to identify status effects
func _is_status_effect(label_type: String) -> bool:
	return label_type in ["poison", "burn", "bleed"]

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
