extends Node

# Call this to play a hit reaction on a target node
func play_hit_effects(target_node: Node):
	if target_node == null:
		print("⚠️ Attempted to hit a null target")
		return
	
	# Camera shake (if BattleCamera exists)
	var cam = get_node_or_null("/root/BattleScene/BattleCamera")
	if cam and cam.has_method("shake"):
		cam.shake(0.3, 4.0)  # duration, intensity
	
	# Hit flash (if FlashLayer exists)
	var flash = get_node_or_null("/root/BattleScene/UILayer/FlashLayer")
	if flash:
		flash_hit(flash)

	# Play block sprite as reaction
	if target_node.has_method("show_block_animation"):
		target_node.show_block_animation()

func flash_hit(flash_node: Node):
	if flash_node == null:
		return
	
	flash_node.visible = true
	var tween = create_tween()
	tween.tween_property(flash_node, "modulate:a", 0.6, 0.05)
	tween.tween_property(flash_node, "modulate:a", 0.0, 0.1)
	await tween.finished
	flash_node.visible = false
