extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var spirit_wave_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/SpiritWaveButton
@onready var uppercut_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/UppercutButton
@onready var whirlwind_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/WhirlwindButton
@onready var big_shot_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/BigShotButton
@onready var scatter_shot_button := $Panel/VBoxContainer/ScrollContainer/ItemsContainer/ScatterShotButton
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

# Store purchased abilities
var purchased_abilities = []

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0

	# Connect buttons
	if spirit_wave_button and not spirit_wave_button.pressed.is_connected(_on_spirit_wave_pressed):
		spirit_wave_button.pressed.connect(_on_spirit_wave_pressed)
	if uppercut_button and not uppercut_button.pressed.is_connected(_on_uppercut_pressed):
		uppercut_button.pressed.connect(_on_uppercut_pressed)
	if whirlwind_button and not whirlwind_button.pressed.is_connected(_on_whirlwind_pressed):
		whirlwind_button.pressed.connect(_on_whirlwind_pressed)
	if big_shot_button and not big_shot_button.pressed.is_connected(_on_big_shot_pressed):
		big_shot_button.pressed.connect(_on_big_shot_pressed)
	if scatter_shot_button and not scatter_shot_button.pressed.is_connected(_on_scatter_shot_pressed):
		scatter_shot_button.pressed.connect(_on_scatter_shot_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_abilities():
	print("ABILITIES→ Showing abilities overlay")

	# Update display with current data
	_update_display()

	# Make visible and fade in
	visible = true
	if spirit_wave_button:
		spirit_wave_button.grab_focus()  # Focus on first ability by default

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_abilities():
	print("ABILITIES→ Hiding abilities overlay")

	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _update_display():
	# Update coins (use ProgressManager if available, otherwise default)
	var coins = 10  # Default for testing
	if has_node("/root/ProgressManager"):
		var progress_manager = get_node("/root/ProgressManager")
		if progress_manager.has_method("get_coins"):
			coins = progress_manager.get_coins()

	coins_label.text = "Coins: " + str(coins)

	# Update ability buttons with ownership status
	spirit_wave_button.text = "Spirit Wave (2 coins) - Ranged spiritual attack" + _get_ability_status("spirit_wave")
	uppercut_button.text = "Uppercut (2 coins) - Rising sword attack" + _get_ability_status("uppercut")
	whirlwind_button.text = "Whirlwind (3 coins) - Spinning attack hitting all enemies" + _get_ability_status("whirlwind")
	big_shot_button.text = "Big Shot (3 coins) - Powerful shot dealing high damage" + _get_ability_status("big_shot")
	scatter_shot_button.text = "Scatter Shot (2 coins) - Spread shot hitting multiple areas" + _get_ability_status("scatter_shot")

	# Disable buttons if not enough coins or already purchased
	spirit_wave_button.disabled = coins < 2 or "spirit_wave" in purchased_abilities
	uppercut_button.disabled = coins < 2 or "uppercut" in purchased_abilities
	whirlwind_button.disabled = coins < 3 or "whirlwind" in purchased_abilities
	big_shot_button.disabled = coins < 3 or "big_shot" in purchased_abilities
	scatter_shot_button.disabled = coins < 2 or "scatter_shot" in purchased_abilities

func _get_ability_status(ability_name: String) -> String:
	if ability_name in purchased_abilities:
		return " [OWNED]"
	return ""

func _buy_ability(ability_name: String, cost: int):
	# Check if we can afford it and don't already own it
	var coins = 10  # Default for testing
	if has_node("/root/ProgressManager"):
		var progress_manager = get_node("/root/ProgressManager")
		if progress_manager.has_method("get_coins"):
			coins = progress_manager.get_coins()

	if coins >= cost and ability_name not in purchased_abilities:
		# Deduct coins (if ProgressManager exists)
		if has_node("/root/ProgressManager"):
			var progress_manager = get_node("/root/ProgressManager")
			if progress_manager.has_method("spend_coins"):
				progress_manager.spend_coins(cost)

		# Add to purchased abilities
		purchased_abilities.append(ability_name)
		print("ABILITIES→ Successfully bought ", ability_name)

		# TODO: Actually unlock the ability for the player
		# This would involve adding it to their available skills

		_update_display()  # Refresh display after purchase
	else:
		print("ABILITIES→ Failed to buy ", ability_name, " - not enough coins or already owned")

func _on_spirit_wave_pressed():
	_buy_ability("spirit_wave", 2)

func _on_uppercut_pressed():
	_buy_ability("uppercut", 2)

func _on_whirlwind_pressed():
	_buy_ability("whirlwind", 3)

func _on_big_shot_pressed():
	_buy_ability("big_shot", 3)

func _on_scatter_shot_pressed():
	_buy_ability("scatter_shot", 2)

func _on_close_pressed():
	print("ABILITIES→ Leaving abilities shop")
	hide_abilities()

	# Advance progression and start next battle
	_start_next_battle()

func _start_next_battle():
	print("ABILITIES→ Starting next battle")

	# Get TurnManager and BackgroundManager for next battle
	var turn_manager = get_node_or_null("/root/BattleScene/TurnManager")
	var background_manager = get_node_or_null("/root/BattleScene/BackgroundManager")
	var background_sprite = get_node_or_null("/root/BattleScene/Background")

	# Change background before starting new battle
	if background_manager and background_sprite:
		background_manager.change_battle_background(background_sprite)
		print("ABILITIES→ Background randomized for next battle")

	if turn_manager:
		# Reset combat for next battle
		turn_manager.reset_combat()
		# Start new turn cycle
		turn_manager.change_state(turn_manager.State.BEGIN_TURN)
		print("ABILITIES→ Next battle started successfully")
	else:
		print("ERROR→ Could not find TurnManager to start next battle")