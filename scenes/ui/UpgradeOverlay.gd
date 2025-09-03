extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var iron_will_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/IronWillButton
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons
	if iron_will_button and not iron_will_button.pressed.is_connected(_on_iron_will_pressed):
		iron_will_button.pressed.connect(_on_iron_will_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_upgrade():
	print("UPGRADE→ Showing upgrade overlay")
	
	# Update display with current data
	_update_display()
	
	# Make visible and fade in
	visible = true
	if iron_will_button:
		iron_will_button.grab_focus()  # Focus on first upgrade by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_upgrade():
	print("UPGRADE→ Hiding upgrade overlay")
	
	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _update_display():
	# Update coins
	coins_label.text = "Coins: " + str(ProgressManager.player_coins)
	
	# Show upgrade status and descriptions
	iron_will_button.text = "Iron Will (1 coin) - Permanent +2 resolve" + _get_upgrade_status("iron_will")
	
	# Disable buttons if not enough coins or already purchased
	var can_afford = ProgressManager.player_coins >= 1
	iron_will_button.disabled = not can_afford or ProgressManager.active_buffs.iron_will

func _get_upgrade_status(upgrade_name: String) -> String:
	if ProgressManager.active_buffs[upgrade_name]:
		return " [OWNED]"
	return ""

func _buy_upgrade(upgrade_name: String):
	if ProgressManager.buy_upgrade(upgrade_name):
		print("UPGRADE→ Successfully bought ", upgrade_name)
		_update_display()  # Refresh display after purchase
	else:
		print("UPGRADE→ Failed to buy ", upgrade_name)

func _on_iron_will_pressed():
	_buy_upgrade("iron_will")

func _on_close_pressed():
	print("UPGRADE→ Leaving upgrade shop")
	hide_upgrade()
	
	# Advance progression and start next battle
	_start_next_battle()

func _start_next_battle():
	print("UPGRADE→ Starting next battle")
	
	# Get TurnManager and start new combat
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	if turn_manager:
		# Reset combat for next battle
		turn_manager.reset_combat()
		# Start new turn cycle
		turn_manager.change_state(turn_manager.State.BEGIN_TURN)
		print("UPGRADE→ Next battle started successfully")
	else:
		print("ERROR→ Could not find TurnManager to start next battle")