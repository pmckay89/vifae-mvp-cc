# attach to: Player1/idle
extends AnimatedSprite2D

func _ready() -> void:
	# Ensure the 'idle' clip exists, make it loop, then play it.
	if sprite_frames and sprite_frames.has_animation("idle"):
		sprite_frames.set_animation_loop("idle", true)
		play("idle")
