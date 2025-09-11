extends Node

# Popup queue system for staggered status effect display
var popup_queue: Array = []
var queue_processing: bool = false
const POPUP_DELAY: float = 0.4  # Delay between sequential popups

# Persistent status effect display
var status_icon_labels: Dictionary = {}  # effect_type -> Label node
var status_icon_container: Control = null

func update_hp_bar(actor_name: String, hp: int, max_hp: int):
	match actor_name:
		"Player1":
			update_player_hp_display("Player1", hp, max_hp)
		"Player2":
			update_player_hp_display("Player2", hp, max_hp)
		"Enemy":
			# Keep old enemy HP system for now
			var path = "/root/BattleScene/UILayer/EnemyHUD/EnemyHPLabel"
			var label = get_node_or_null(path)
			if label:
				label.text = "BOSS HP: " + str(hp) + "/" + str(max_hp)
			else:
				print("⚠️ Could not find enemy HP bar at " + path)
		_:
			print("⚠️ Unknown actor name: " + actor_name)

func update_player_hp_display(player: String, hp: int, max_hp: int):
	# Update HP text label
	var hp_label_path = "/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/" + player + "Row/" + player + "Info/" + player + "Header/" + player + "HP"
	var hp_label = get_node_or_null(hp_label_path)
	if hp_label:
		hp_label.text = str(hp) + "/" + str(max_hp)
	else:
		print("⚠️ Could not find " + player + " HP label at " + hp_label_path)
	
	# Update HP progress bar
	var hp_bar_path = "/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/" + player + "Row/" + player + "Info/" + player + "ProgressContainer/" + player + "HPBar"
	var hp_bar = get_node_or_null(hp_bar_path)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		
		# Color HP bar based on health percentage
		var health_percent = float(hp) / float(max_hp)
		var hp_fill_style = hp_bar.get_theme_stylebox("fill")
		if hp_fill_style:
			if health_percent > 0.6:
				hp_fill_style.bg_color = Color(0.2, 0.8, 0.2, 1)  # Green
			elif health_percent > 0.3:
				hp_fill_style.bg_color = Color(0.8, 0.8, 0.2, 1)  # Yellow
			else:
				hp_fill_style.bg_color = Color(0.8, 0.2, 0.2, 1)  # Red
	else:
		print("⚠️ Could not find " + player + " HP bar at " + hp_bar_path)

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
	
	# DEBUG: Log all shield effect calls
	if effect_type == "shield":
		print("🛡️ [DEBUG] Shield popup called - Target: ", target_node.name, " Type: ", effect_type)
	
	# Shield is a player-only buff - never show on enemies
	if effect_type == "shield" and target_node.name.begins_with("Enemy"):
		print("🛡️ [BUG BLOCKED] Shield is player-only - skipping enemy display")
		return
	
	# Check if target is a player and route player-compatible effects to FF-style status area
	if target_node.name == "Player1" or target_node.name == "Player2":
		# Only show certain effects on players (not enemy-specific effects)
		var player_effects = ["burn", "poison", "bleed", "shield", "mark", "vulnerable", "stun", "regeneration", "frozen", "damage_boost", "critical_boost", "armor_up", "reflect", "focus", "resolve_gain", "confusion"]
		if effect_type in player_effects:
			show_player_status_icon(target_node.name, effect_type)
			print("🎯 [CombatUI] Routed " + effect_type + " status to " + target_node.name + " FF-style container")
		else:
			print("🎯 [CombatUI] Skipped " + effect_type + " - not a player effect")
	elif target_node.name.begins_with("Enemy"):
		# Only show enemy-specific effects on enemies (shield is NEVER an enemy effect)
		var enemy_effects = ["armor_down", "frozen", "burn", "poison", "bleed", "mark", "vulnerable", "stun"]
		if effect_type in enemy_effects:
			show_status_icon(effect_type)  # Use enemy status container
			print("🎯 [CombatUI] Routed " + effect_type + " status to enemy container")
		else:
			print("🎯 [CombatUI] Skipped " + effect_type + " - not an enemy effect")
	
	# Still show popup for visual feedback
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

# Initialize status icon container - now routes to player-specific areas
func _ensure_status_container(target_node: Node = null):
	# This function is now mainly for enemy status effects
	# Player status effects use the new show_player_status_icon function
	if status_icon_container != null:
		return
	
	var ui_layer = get_node_or_null("/root/BattleScene/UILayer")
	if not ui_layer:
		print("⚠️ Could not find UILayer for status container")
		return
	
	# Create container for enemy status icons
	status_icon_container = Control.new()
	status_icon_container.name = "EnemyStatusIconContainer"
	
	# Position container near enemy HP area
	status_icon_container.position = Vector2(900, 550)  # Bottom-right area near enemy HP
	status_icon_container.size = Vector2(200, 50)  # Container size
	
	ui_layer.add_child(status_icon_container)
	print("🎯 [CombatUI] Created enemy status icon container at position (900, 550)")

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
		"regeneration": {"icon": "💚", "color": Color(0.2, 1.0, 0.2, 1.0)},
		"frozen": {"icon": "❄️", "color": Color(0.5, 0.8, 1.0, 1.0)},
		"armor_down": {"icon": "⚔️", "color": Color(0.8, 0.6, 0.2, 1.0)},
		"damage_boost": {"icon": "💪", "color": Color(1.0, 0.6, 0.0, 1.0)},
		"critical_boost": {"icon": "⭐", "color": Color(1.0, 1.0, 0.0, 1.0)},
		"armor_up": {"icon": "🛡️", "color": Color(0.6, 0.6, 0.8, 1.0)},
		"reflect": {"icon": "🔄", "color": Color(0.8, 0.4, 1.0, 1.0)},
		"focus": {"icon": "🎯", "color": Color(0.0, 1.0, 1.0, 1.0)},
		"resolve_gain": {"icon": "⚡", "color": Color(1.0, 1.0, 0.0, 1.0)},
		"confusion": {"icon": "😵‍💫", "color": Color(1.0, 0.4, 1.0, 1.0)}
	}
	return icon_data.get(effect_type, {"icon": "⚡", "color": Color.WHITE})

# Player-specific status effects - routes to correct player container
func show_player_status_icon(player_name: String, effect_type: String):
	print("🎯 [CombatUI] Showing " + effect_type + " icon for " + player_name)
	
	# Get the correct player status area
	var status_area_path = "/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/" + player_name + "Row/" + player_name + "StatusArea"
	var status_area = get_node_or_null(status_area_path)
	
	if not status_area:
		print("⚠️ Could not find status area for " + player_name + " at " + status_area_path)
		return
	
	# Don't create duplicate icons for this player
	var icon_key = player_name + "_" + effect_type
	if icon_key in status_icon_labels:
		print("🔍 [DEBUG] Icon already exists for " + icon_key)
		return
	
	# Create status icon label
	var icon_label = Label.new()
	icon_label.name = "StatusIcon_" + effect_type
	
	# Set icon and color based on effect type
	var icon_data = _get_status_icon_data(effect_type)
	icon_label.text = icon_data.icon
	icon_label.modulate = icon_data.color
	icon_label.add_theme_font_size_override("font_size", 24)
	
	status_area.add_child(icon_label)
	status_icon_labels[icon_key] = icon_label
	
	print("🎯 [CombatUI] Created " + effect_type + " icon for " + player_name + " in FF-style container")

func hide_player_status_icon(player_name: String, effect_type: String):
	var icon_key = player_name + "_" + effect_type
	if icon_key in status_icon_labels:
		var icon_label = status_icon_labels[icon_key]
		if icon_label and is_instance_valid(icon_label):
			icon_label.queue_free()
		status_icon_labels.erase(icon_key)
		print("🎯 [CombatUI] Hidden " + effect_type + " icon for " + player_name)

# Update resolve display
func update_resolve_display(player_name: String, resolve_count: int):
	var resolve_label_path = "/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/" + player_name + "Row/" + player_name + "Info/" + player_name + "Header/" + player_name + "ResolveCount"
	var resolve_label = get_node_or_null(resolve_label_path)
	if resolve_label:
		resolve_label.text = str(resolve_count)
		print("🎯 [CombatUI] Updated " + player_name + " resolve display: " + str(resolve_count))
	else:
		print("⚠️ Could not find resolve label for " + player_name + " at " + resolve_label_path)

# Update turn indicator to show whose turn it is
func update_turn_indicator(current_player: String):
	# Hide all turn indicators first
	var player1_indicator = get_node_or_null("/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/Player1Row/Player1Info/Player1Header/Player1TurnIndicator")
	var player2_indicator = get_node_or_null("/root/BattleScene/UILayer/PlayerUIContainer/PlayersVBox/Player2Row/Player2Info/Player2Header/Player2TurnIndicator")
	
	if player1_indicator:
		player1_indicator.visible = false
	if player2_indicator:
		player2_indicator.visible = false
	
	# Show indicator for current player
	if current_player == "Player1" and player1_indicator:
		player1_indicator.visible = true
		print("🎯 [CombatUI] Showing turn indicator for Player1")
	elif current_player == "Player2" and player2_indicator:
		player2_indicator.visible = true
		print("🎯 [CombatUI] Showing turn indicator for Player2")
	else:
		print("🎯 [CombatUI] Turn indicator hidden (enemy turn or unknown player)")
