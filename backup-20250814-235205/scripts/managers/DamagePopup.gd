extends Node2D

@onready var label: Label = $Label

func show_damage(value: int, label_type: String = "damage"):
	label.text = str(value)

	match label_type:
		"damage":
			label.modulate = Color(1, 1, 1)
		"crit":
			label.modulate = Color(1, 0.2, 0.2)
		"heal":
			label.modulate = Color(0.2, 1, 0.2)
		"miss":
			label.modulate = Color(0.7, 0.7, 0.7, 0.5)
		_:
			label.modulate = Color(1, 1, 1)

	call_deferred("_start_tween")

func _start_tween():
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -30), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(Callable(self, "queue_free"))
