extends Node

# All available arena backgrounds
var valid_arenas = ["arena", "arena2", "arena3", "arena4", "arena5", "arena6", "arena7", "arena8", "arena9", "arena10"]
var current_arena: String = ""

func _ready():
	# Seed the random number generator for true randomization
	randomize()
	print("BACKGROUND→ BackgroundManager initialized with random seed")

func get_random_arena() -> String:
	var selected = valid_arenas[randi() % valid_arenas.size()]
	print("BACKGROUND→ Selected random arena: ", selected)
	return selected

func change_battle_background(background_node: Sprite2D):
	if not background_node:
		print("ERROR→ BackgroundManager: No background node provided")
		return
		
	var new_arena = get_random_arena()
	current_arena = new_arena
	
	var texture_path = "res://assets/backgrounds/" + new_arena + ".png"
	var new_texture = load(texture_path)
	
	if new_texture:
		background_node.texture = new_texture
		print("BACKGROUND→ Successfully changed to: ", texture_path)
	else:
		print("ERROR→ BackgroundManager: Failed to load texture: ", texture_path)

func get_current_arena() -> String:
	return current_arena