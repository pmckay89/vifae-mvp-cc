extends Camera2D

var shake_timer := 0.0
var shake_intensity := 0.0
var original_position := Vector2.ZERO

func _ready():
	make_current()
	original_position = global_position

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		var shake_offset = Vector2(
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * shake_intensity
		global_position = original_position + shake_offset
	else:
		global_position = original_position

func shake(duration: float, intensity: float):
	shake_timer = duration
	shake_intensity = intensity
