extends Control

@onready var title_label := $Panel/VBoxContainer/Title
@onready var coins_label := $Panel/VBoxContainer/CoinsLabel
@onready var path_a_button := $Panel/VBoxContainer/ChoiceContainer/PathAButton
@onready var path_b_button := $Panel/VBoxContainer/ChoiceContainer/PathBButton
@onready var close_button := $Panel/VBoxContainer/CloseButton
@onready var panel := $Panel

func _ready():
	# Start invisible
	visible = false
	modulate.a = 0.0
	
	# Connect buttons
	if path_a_button and not path_a_button.pressed.is_connected(_on_path_a_pressed):
		path_a_button.pressed.connect(_on_path_a_pressed)
	if path_b_button and not path_b_button.pressed.is_connected(_on_path_b_pressed):
		path_b_button.pressed.connect(_on_path_b_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_map():
	print("MAP→ Showing map overlay")
	
	# Update display with current progress data
	_update_display()
	
	# Make visible and fade in
	visible = true
	if path_a_button:
		path_a_button.grab_focus()  # Focus on first choice by default
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_map():
	print("MAP→ Hiding map overlay")
	
	# Fade out and hide
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false

func _update_display():
	# Update coins display
	coins_label.text = "Coins: " + str(ProgressManager.player_coins)
	
	# Get available choices from ProgressManager
	var choices = ProgressManager.get_available_choices()
	
	if choices.size() >= 2:
		# Update button texts with choice types
		path_a_button.text = "Path A: " + choices[0].name
		path_b_button.text = "Path B: " + choices[1].name
		
		# Show buttons
		path_a_button.visible = true
		path_b_button.visible = true
	else:
		# No choices available (end of map?)
		path_a_button.visible = false
		path_b_button.visible = false
		title_label.text = "Journey Complete!"

func _on_path_a_pressed():
	print("MAP→ Path A selected")
	_choose_path("A")

func _on_path_b_pressed():
	print("MAP→ Path B selected") 
	_choose_path("B")

func _choose_path(path: String):
	# Tell ProgressManager about the choice
	ProgressManager.choose_path(path)
	
	# Get the chosen node type to determine which overlay to show
	var choices = ProgressManager.get_available_choices()
	var chosen_type
	
	if path == "A" and choices.size() > 0:
		chosen_type = choices[0].type
	elif path == "B" and choices.size() > 1:
		chosen_type = choices[1].type
	else:
		print("ERROR→ Invalid path choice or no choices available")
		return
	
	# Hide map and show appropriate overlay
	hide_map()
	await get_tree().create_timer(0.4).timeout  # Wait for fade out
	
	# Signal to TurnManager to change state
	match chosen_type:
		ProgressManager.NodeType.SHOP:
			_show_shop()
		ProgressManager.NodeType.UPGRADE:
			_show_upgrade()
		_:
			print("MAP→ Unknown node type: ", chosen_type)

func _show_shop():
	print("MAP→ Opening shop...")
	var shop_overlay = get_node_or_null("/root/BattleScene/UILayer/ShopOverlay")
	if shop_overlay and shop_overlay.has_method("show_shop"):
		shop_overlay.show_shop()
	else:
		print("ERROR→ ShopOverlay not found!")
	
func _show_upgrade():
	print("MAP→ Opening upgrades...")
	# TODO: Create and connect UpgradeOverlay
	print("MAP→ Upgrade overlay not implemented yet")

func _on_close_pressed():
	print("MAP→ Close button pressed")
	hide_map()
	# TODO: Return to previous state (probably combat or victory screen)