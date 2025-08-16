extends Control
class_name QTEWidget

# QTE Widget for modular visual feedback
# Handles ring expansion, input prompts, and success/fail animations

@onready var ring_empty: Sprite2D
@onready var ring_fill: Sprite2D
@onready var input_prompt: Sprite2D
@onready var effect_sprite: Sprite2D

var current_progress: float = 0.0
var is_active: bool = false
var fill_tween: Tween

func _ready():
	# Create the UI elements
	setup_ring_elements()
	setup_input_prompt()
	setup_effect_sprite()
	
	# Start hidden
	visible = false
	
	print("[QTEWidget] Ready - ring expansion system loaded")

func setup_ring_elements():
	# Create empty ring (background)
	ring_empty = Sprite2D.new()
	ring_empty.name = "RingEmpty"
	
	# Try to load ring empty texture, fallback to existing QTE texture
	var empty_texture = load("res://assets/ui/qte_ring_empty.png")
	if empty_texture == null:
		empty_texture = load("res://assets/ui/QTE.png")  # Fallback to existing
		print("[QTEWidget] Using fallback texture for ring empty")
	ring_empty.texture = empty_texture
	ring_empty.scale = Vector2(0.5, 0.5)  # Start smaller
	add_child(ring_empty)
	
	# Create fill ring (progress)
	ring_fill = Sprite2D.new()
	ring_fill.name = "RingFill"
	
	# Try to load ring fill texture, fallback to existing QTE texture
	var fill_texture = load("res://assets/ui/qte_ring_fill.png")
	if fill_texture == null:
		fill_texture = load("res://assets/ui/QTE.png")  # Fallback to existing
		print("[QTEWidget] Using fallback texture for ring fill")
	ring_fill.texture = fill_texture
	ring_fill.scale = Vector2(0.1, 0.1)  # Start very small
	ring_fill.modulate = Color.GREEN  # Tint it differently for visibility
	add_child(ring_fill)
	
	print("[QTEWidget] Ring elements created")

func setup_input_prompt():
	# Create input prompt sprite
	input_prompt = Sprite2D.new()
	input_prompt.name = "InputPrompt"
	input_prompt.position = Vector2(0, -80)  # Above the ring
	add_child(input_prompt)

func setup_effect_sprite():
	# Create effect sprite for success/fail feedback
	effect_sprite = Sprite2D.new()
	effect_sprite.name = "EffectSprite"
	effect_sprite.visible = false
	add_child(effect_sprite)

func start_qte(qte_type: String, prompt_key: String = "Z"):
	"""Start a QTE with specified type and input prompt"""
	print("[QTEWidget] Starting QTE type: " + qte_type + " with prompt: " + prompt_key)
	print("[QTEWidget] Ring empty texture: ", ring_empty.texture)
	print("[QTEWidget] Ring fill texture: ", ring_fill.texture)
	
	is_active = true
	current_progress = 0.0
	visible = true
	
	print("[QTEWidget] Widget is now visible at position: ", global_position)
	print("[QTEWidget] Widget visible: ", visible)
	print("[QTEWidget] Ring empty visible: ", ring_empty.visible)
	print("[QTEWidget] Ring fill visible: ", ring_fill.visible)
	print("[QTEWidget] Ring empty position: ", ring_empty.position)
	print("[QTEWidget] Ring fill position: ", ring_fill.position)
	
	# Set input prompt based on key (with fallbacks)
	match prompt_key:
		"Z":
			var z_texture = load("res://assets/ui/prompt_z.png")
			if z_texture == null:
				print("[QTEWidget] prompt_z.png not found, using placeholder")
			input_prompt.texture = z_texture
		"X":
			var x_texture = load("res://assets/ui/prompt_x.png")
			if x_texture == null:
				print("[QTEWidget] prompt_x.png not found, using placeholder")
			input_prompt.texture = x_texture
		"RAPID":
			var rapid_texture = load("res://assets/ui/prompt_rapid.png")
			if rapid_texture == null:
				print("[QTEWidget] prompt_rapid.png not found, using placeholder")
			input_prompt.texture = rapid_texture
	
	# Reset ring scales
	ring_empty.scale = Vector2(0.5, 0.5)
	ring_fill.scale = Vector2(0.1, 0.1)
	
	# Position at screen center
	var screen_center = get_viewport().get_visible_rect().size / 2
	# Since we're in a fullscreen container, just center the rings within it
	position = Vector2.ZERO  # Reset position
	ring_empty.position = screen_center
	ring_fill.position = screen_center
	input_prompt.position = screen_center + Vector2(0, -80)

func update_progress(progress: float):
	"""Update QTE progress (0.0 to 1.0)"""
	if not is_active:
		return
		
	current_progress = clamp(progress, 0.0, 1.0)
	
	# Expand fill ring based on progress
	var base_scale = 0.1
	var max_scale = 0.5
	var target_scale = base_scale + (progress * (max_scale - base_scale))
	ring_fill.scale = Vector2(target_scale, target_scale)

func show_success():
	"""Show success animation"""
	print("[QTEWidget] Success!")
	
	# Load and show success effect (with fallback)
	var success_texture = load("res://assets/ui/qte_success.png")
	if success_texture == null:
		print("[QTEWidget] qte_success.png not found, skipping effect")
		end_qte()
		return
	effect_sprite.texture = success_texture
	effect_sprite.visible = true
	effect_sprite.scale = Vector2(0.5, 0.5)
	
	# Success burst animation
	if fill_tween:
		fill_tween.kill()
	fill_tween = create_tween()
	fill_tween.parallel().tween_property(effect_sprite, "scale", Vector2(1.2, 1.2), 0.2)
	fill_tween.parallel().tween_property(effect_sprite, "modulate", Color(1, 1, 1, 0), 0.3)
	fill_tween.tween_callback(end_qte)

func show_failure():
	"""Show failure animation"""
	print("[QTEWidget] Failure!")
	
	# Load and show fail effect (with fallback)
	var fail_texture = load("res://assets/ui/qte_fail.png")
	if fail_texture == null:
		print("[QTEWidget] qte_fail.png not found, skipping effect")
		end_qte()
		return
	effect_sprite.texture = fail_texture
	effect_sprite.visible = true
	effect_sprite.scale = Vector2(0.8, 0.8)
	effect_sprite.modulate = Color.RED
	
	# Failure shake animation
	if fill_tween:
		fill_tween.kill()
	fill_tween = create_tween()
	fill_tween.parallel().tween_property(self, "position", position + Vector2(10, 0), 0.05)
	fill_tween.parallel().tween_property(self, "position", position - Vector2(10, 0), 0.05)
	fill_tween.parallel().tween_property(self, "position", position, 0.05)
	fill_tween.parallel().tween_property(effect_sprite, "modulate", Color(1, 0, 0, 0), 0.3)
	fill_tween.tween_callback(end_qte)

func end_qte():
	"""Clean up and hide QTE"""
	print("[QTEWidget] QTE ended")
	
	is_active = false
	visible = false
	effect_sprite.visible = false
	effect_sprite.modulate = Color.WHITE
	current_progress = 0.0
	
	if fill_tween:
		fill_tween.kill()