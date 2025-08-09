extends Node

func update_hp_bar(actor_name: String, hp: int, max_hp: int):
	var path = ""
	var display_name = ""
	
	match actor_name:
		"Player1":
			path = "/root/BattleScene/UILayer/HPBars/Player1HP"
			display_name = "SWORD SPIRIT"
		"Player2":
			path = "/root/BattleScene/UILayer/HPBars/Player2HP"
			display_name = "GUN GIRL"
		"Enemy":
			path = "/root/BattleScene/UILayer/HPBars/EnemyHP"
			display_name = "TITAN SPARK"
		_:
			print("⚠️ Unknown actor name: " + actor_name)
			return
	
	var label = get_node_or_null(path)
	if label:
		label.text = display_name + ": " + str(hp) + "/" + str(max_hp)
	else:
		print("⚠️ Could not find HP bar at " + path)

func show_damage_popup(target_node: Node, amount: int):
	if target_node == null:
		print("⚠️ Cannot show damage popup on null target")
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		print("⚠️ Could not load DamagePopup.tscn")
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(90, -50)
	popup.show_damage(amount)
