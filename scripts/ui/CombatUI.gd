extends Node

# Popup queue system for staggered status effect display
var popup_queue: Array = []
var queue_processing: bool = false
const POPUP_DELAY: float = 0.4  # Delay between sequential popups

# Persistent status effect display
var status_icon_labels: Dictionary = {}  # effect_type -> Label node
var status_icon_container: Control = null

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
			path = "/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel"
			display_name = "BOSS HP"
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

func show_poison_popup(target_node: Node, amount: int):
	if target_node == null:
		print("⚠️ Cannot show poison popup on null target")
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		print("⚠️ Could not load DamagePopup.tscn for poison")
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(90, -80)  # Slightly different position than normal damage
	
	# Show poison damage with different styling if possible
	if popup.has_method("show_poison_damage"):
		popup.show_poison_damage(amount)
	else:
		popup.show_damage(amount)  # Fallback to normal damage display

# Status effect application popups - queued for staggered display
func show_status_applied_popup(target_node: Node, effect_type: String):
	if target_node == null:
		print("⚠️ Cannot show status popup on null target")
		return
	
	# Add to queue instead of showing immediately
	var popup_data = {
		"target": target_node,
		"effect_type": effect_type,
		"type": "status_application"
	}
	
	popup_queue.append(popup_data)
	_process_popup_queue()

# Process the popup queue with staggered timing
func _process_popup_queue():
	if queue_processing or popup_queue.is_empty():
		return
	
	queue_processing = true
	
	while not popup_queue.is_empty():
		var popup_data = popup_queue.pop_front()
		_show_popup_immediately(popup_data)
		
		# Wait before showing next popup
		if not popup_queue.is_empty():
			await get_tree().create_timer(POPUP_DELAY).timeout
	
	queue_processing = false

# Actually display a popup immediately
func _show_popup_immediately(popup_data: Dictionary):
	var target_node = popup_data.get("target")
	var effect_type = popup_data.get("effect_type")
	var popup_type = popup_data.get("type")
	
	if not target_node or not is_instance_valid(target_node):
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		print("⚠️ Could not load DamagePopup.tscn")
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(50, -120)  # Simple center position
	
	if popup_type == "status_application":
		# Status effect messages
		var messages = {
			"burn": "BURNED!",
			"poison": "POISONED!",
			"shield": "SHIELDED!",
			"mark": "MARKED!",
			"vulnerable": "VULNERABLE!",
			"stun": "STUNNED!",
			"confusion": "CONFUSED!",
			"regeneration": "REGENERATING!",
			"damage_boost": "POWERED UP!",
			"critical_boost": "CRITICAL!",
			"armor_up": "ARMORED!",
			"reflect": "REFLECTING!",
			"focus": "FOCUSED!",
			"resolve_gain": "ENERGIZED!",
			"bleed": "BLEEDING!"
		}
		
		var message = messages.get(effect_type, effect_type.to_upper() + "!")
		
		if popup.has_method("show_status_effect"):
			popup.show_status_effect(message, effect_type)
		else:
			popup.show_damage(0)

# Burn DOT damage popup (similar to poison)
func show_burn_popup(target_node: Node, amount: int):
	if target_node == null:
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(110, -80)  # Different from poison position
	
	if popup.has_method("show_burn_damage"):
		popup.show_burn_damage(amount)
	else:
		popup.show_damage(amount)

# Bleed DOT damage popup
func show_bleed_popup(target_node: Node, amount: int):
	if target_node == null:
		return
	
	var popup_scene = load("res://scenes/DamagePopup.tscn")
	if popup_scene == null:
		return
	
	var popup = popup_scene.instantiate()
	target_node.add_child(popup)
	popup.position = Vector2(70, -80)  # Different from other DOT positions
	
	if popup.has_method("show_bleed_damage"):
		popup.show_bleed_damage(amount)
	else:
		popup.show_damage(amount)

# Initialize status icon container (called once)
func _ensure_status_container():
	if status_icon_container != null:
		return
	
	var ui_layer = get_node_or_null("/root/BattleScene/UILayer")
	if not ui_layer:
		print("⚠️ Could not find UILayer for status container")
		return
	
	# Create container for status icons
	status_icon_container = Control.new()
	status_icon_container.name = "StatusIconContainer"
	
	# Position container near enemy HP area (adjust these coordinates as needed)
	status_icon_container.position = Vector2(900, 550)  # Bottom-right area near enemy HP
	status_icon_container.size = Vector2(200, 50)  # Container size
	
	ui_layer.add_child(status_icon_container)
	print("🎯 [CombatUI] Created status icon container at position (900, 550)")

# Persistent status effect icon system
func show_status_icon(effect_type: String):
	print("🔍 [DEBUG] Attempting to show status icon for: ", effect_type)
	
	# Ensure container exists
	_ensure_status_container()
	if not status_icon_container:
		return
	
	# Don't create duplicate icons
	if effect_type in status_icon_labels:
		print("🔍 [DEBUG] Icon already exists for ", effect_type)
		return
	
	# Create status icon label
	var icon_label = Label.new()
	icon_label.name = "StatusIcon_" + effect_type
	
	# Set icon and color based on effect type
	var icon_data = _get_status_icon_data(effect_type)
	icon_label.text = icon_data.icon
	icon_label.modulate = icon_data.color
	icon_label.add_theme_font_size_override("font_size", 28)
	
	# Position within container (stack horizontally)
	var icon_count = status_icon_labels.size()
	icon_label.position = Vector2(icon_count * 35, 0)  # Stack icons horizontally
	
	print("🔍 [DEBUG] Container position: ", status_icon_container.position)
	print("🔍 [DEBUG] Icon local position: ", icon_label.position)
	print("🔍 [DEBUG] Icon text: '", icon_data.icon, "' color: ", icon_data.color)
	print("🔍 [DEBUG] Container visible: ", status_icon_container.visible)
	print("🔍 [DEBUG] Icon visible: ", icon_label.visible)
	print("🔍 [DEBUG] Container children count: ", status_icon_container.get_child_count())
	
	status_icon_container.add_child(icon_label)
	status_icon_labels[effect_type] = icon_label
	
	print("🎯 [CombatUI] Created persistent ", effect_type, " icon in container")

func hide_status_icon(effect_type: String):
	if effect_type in status_icon_labels:
		var icon_label = status_icon_labels[effect_type]
		if icon_label and is_instance_valid(icon_label):
			icon_label.queue_free()
		status_icon_labels.erase(effect_type)
		print("🎯 [CombatUI] Hidden persistent ", effect_type, " icon")

func _get_status_icon_data(effect_type: String) -> Dictionary:
	var icon_data = {
		"burn": {"icon": "🔥", "color": Color(1.0, 0.4, 0.1, 1.0)},
		"poison": {"icon": "☠️", "color": Color(0.2, 0.8, 0.2, 1.0)},
		"bleed": {"icon": "🩸", "color": Color(0.8, 0.1, 0.1, 1.0)},
		"shield": {"icon": "🛡️", "color": Color(0.4, 0.8, 1.0, 1.0)},
		"mark": {"icon": "🎯", "color": Color(1.0, 0.8, 0.0, 1.0)},
		"vulnerable": {"icon": "💥", "color": Color(1.0, 0.2, 0.2, 1.0)},
		"stun": {"icon": "😵", "color": Color(0.8, 0.8, 0.2, 1.0)},
		"regeneration": {"icon": "💚", "color": Color(0.2, 1.0, 0.2, 1.0)}
	}
	return icon_data.get(effect_type, {"icon": "⚡", "color": Color.WHITE})
