extends Node

func shake(magnitude: float, duration: float) -> void:
	var camera = get_node_or_null("/root/BattleScene/BattleCamera")
	if camera and camera.has_method("shake"):
		camera.shake(duration, magnitude)
		print("📳 ScreenShake: magnitude=" + str(magnitude) + " duration=" + str(duration))
	else:
		print("⚠️ ScreenShake: BattleCamera not found")
