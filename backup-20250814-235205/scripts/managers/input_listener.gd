extends Node

func _input(event):
	if event.is_action_pressed("move up"):
		print("Move Up")
	elif event.is_action_pressed("move down"):
		print("Move Down")
	elif event.is_action_pressed("move left"):
		print("Move Left")
	elif event.is_action_pressed("move right"):
		print("Move Right")
	elif event.is_action_pressed("confirm attack"):
		print("Confirm Attack")
	elif event.is_action_pressed("cancel dodge"):
		print("Cancel Dodge")
	elif event.is_action_pressed("parry"):
		print("Parry")
	elif event.is_action_pressed("start"):
		print("Start Pressed")
