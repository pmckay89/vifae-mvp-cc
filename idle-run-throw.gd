extends AnimatedSprite2D

@onready var animation_player = $AnimationPlayer

func _ready():
	play("idle")

func perform_attack():
	animation_player.play("grenade_attack")
