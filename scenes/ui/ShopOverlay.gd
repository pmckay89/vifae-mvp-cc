extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var hp_potion_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/HPPotionButton
@onready var resolve_potion_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/ResolvePotionButton
@onready var power_boost_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/PowerBoostButton
@onready var quick_reflexes_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/QuickReflexesButton
@onready var iron_will_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/IronWillButton
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons
	if hp_potion_button and not hp_potion_button.pressed.is_connected(_on_hp_potion_pressed):
		hp_potion_button.pressed.connect(_on_hp_potion_pressed)
	if resolve_potion_button and not resolve_potion_button.pressed.is_connected(_on_resolve_potion_pressed):
		resolve_potion_button.pressed.connect(_on_resolve_potion_pressed)
	if power_boost_button and not power_boost_button.pressed.is_connected(_on_power_boost_pressed):
		power_boost_button.pressed.connect(_on_power_boost_pressed)
	if quick_reflexes_button and not quick_reflexes_button.pressed.is_connected(_on_quick_reflexes_pressed):
		quick_reflexes_button.pressed.connect(_on_quick_reflexes_pressed)
	if iron_will_button and not iron_will_button.pressed.is_connected(_on_iron_will_pressed):
		iron_will_button.pressed.connect(_on_iron_will_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_shop():
	print("SHOP→ Showing shop overlay")
	
	# Update display with current data
	_update_display()
	
	# Make visible and fade in
	visible = true
	if hp_potion_button:
		hp_potion_button.grab_focus()  # Focus on first item by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_shop():
	print("SHOP→ Hiding shop overlay")
	
	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _update_display():
	# Update coins
	coins_label.text = "Coins: " + str(ProgressManager.player_coins)
	
	# Update item counts and buff status
	var hp_count = ProgressManager.get_party_item_count("hp_potion")
	var resolve_count = ProgressManager.get_party_item_count("resolve_potion")
	
	hp_potion_button.text = "HP Potion (1 coin) - Have: " + str(hp_count)
	resolve_potion_button.text = "Resolve Potion (1 coin) - Have: " + str(resolve_count)
	
	# Show buff status
	power_boost_button.text = "Power Boost (1 coin) - 2x damage next battle" + _get_buff_status("power_boost")
	quick_reflexes_button.text = "Quick Reflexes (1 coin) - Slower QTE windows" + _get_buff_status("quick_reflexes")
	iron_will_button.text = "Iron Will (1 coin) - +2 resolve next battle" + _get_buff_status("iron_will")
	
	# Disable buttons if not enough coins
	var can_afford = ProgressManager.player_coins >= 1
	hp_potion_button.disabled = not can_afford
	resolve_potion_button.disabled = not can_afford
	power_boost_button.disabled = not can_afford or ProgressManager.active_buffs.power_boost
	quick_reflexes_button.disabled = not can_afford or ProgressManager.active_buffs.quick_reflexes  
	iron_will_button.disabled = not can_afford or ProgressManager.active_buffs.iron_will

func _get_buff_status(buff_name: String) -> String:
	if ProgressManager.active_buffs[buff_name]:
		return " [ACTIVE]"
	return ""

func _buy_item(item_name: String):
	if ProgressManager.buy_item(item_name):
		print("SHOP→ Successfully bought ", item_name)
		_update_display()  # Refresh display after purchase
	else:
		print("SHOP→ Failed to buy ", item_name)

func _on_hp_potion_pressed():
	_buy_item("hp_potion")

func _on_resolve_potion_pressed():
	_buy_item("resolve_potion")

func _on_power_boost_pressed():
	_buy_item("power_boost")

func _on_quick_reflexes_pressed():
	_buy_item("quick_reflexes")

func _on_iron_will_pressed():
	_buy_item("iron_will")

func _on_close_pressed():
	print("SHOP→ Leaving shop")
	hide_shop()
	# TODO: Return to map or continue to next battle