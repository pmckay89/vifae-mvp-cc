extends Node

# ===== ANIMATION BRIDGE SYSTEM =====
# Spawns and controls animations from library scenes
# Enables reusable, position-aware animation sequences

signal animation_ready_for_qte(ability_name: String)
signal animation_sequence_complete(ability_name: String)

# Animation library - maps ability names to scene paths and configurations
var animation_library = {
	"grenade": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "grenade_windup",
		"success_animation": "grenade_success", 
		"fail_animation": "hitstun",
		"spawn_offset": Vector2(0, 0) # Offset from player position
	},
	"bullet_rain": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "idle",
		"success_animation": "bullet rain", 
		"fail_animation": "hitstun",
		"spawn_offset": Vector2(0, 0) # Offset from player position
	},
	"drink": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "drink",
		"success_animation": "drink", 
		"fail_animation": "drink", # Same animation for all results
		"spawn_offset": Vector2(0, 0) # Offset from player position
	},
	"basic_attack": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "attack_windup",
		"success_animation": "attack_finish", 
		"fail_animation": "hitstun",
		"spawn_offset": Vector2(0, 0) # Offset from player position
	}
}

# Active animation instances
var active_animations = {}

func spawn_ability_animation(ability_name: String, spawn_position: Vector2, player_node: Node2D):
	print("🎬 [AnimationBridge] Spawning animation for: ", ability_name)
	
	var config = animation_library.get(ability_name)
	if not config:
		print("❌ [AnimationBridge] No animation config for: ", ability_name)
		return null
	
	# Load and instantiate animation scene
	var animation_scene = load(config.scene_path)
	if not animation_scene:
		print("❌ [AnimationBridge] Could not load scene: ", config.scene_path)
		return null
	
	var animation_instance = animation_scene.instantiate()
	get_tree().current_scene.add_child(animation_instance)
	
	# Move to front so explosions appear over enemies
	animation_instance.z_index = 100
	
	# Position and scale the animation using scene positions
	animation_instance.global_position = Vector2(0, 0)  # Keep at origin
	animation_instance.scale = Vector2(1.0, 1.0)
	
	# Keep HeroRoot at its original scene position - animations are already correctly aligned
	var hero_root = animation_instance.get_node_or_null("HeroRoot")
	if hero_root:
		print("🎬 [AnimationBridge] Using original HeroRoot position: ", hero_root.position)
	
	# Hide the camera and enemy dummy from the testing scene
	var camera = animation_instance.get_node_or_null("Camera2D")
	if camera:
		camera.enabled = false
	var enemy_dummy = animation_instance.get_node_or_null("EnemyDummy")  
	if enemy_dummy:
		enemy_dummy.visible = false
	
	print("🎬 [AnimationBridge] Animation instance spawned at origin")
	print("🎬 [AnimationBridge] Instance scale: ", animation_instance.scale)
	print("🎬 [AnimationBridge] HeroRoot position: ", hero_root.position if hero_root else "not found")
	
	# Debug the scene tree structure
	print("🔍 [AnimationBridge] Scene tree structure:")
	_debug_print_children(animation_instance, "", 0)
	
	# Hide player's idle animation during grenade attack
	var player_idle_sprite = player_node.get_node_or_null("IdleAnimatedSprite")
	if player_idle_sprite:
		player_idle_sprite.visible = false
		print("🎬 [AnimationBridge] Hidden player idle animation")
	
	# Store reference
	active_animations[ability_name] = {
		"instance": animation_instance,
		"config": config,
		"player_node": player_node,
		"player_idle_sprite": player_idle_sprite
	}
	
	return animation_instance

func play_windup_animation(ability_name: String):
	print("🎬 [AnimationBridge] Playing windup for: ", ability_name)
	
	var anim_data = active_animations.get(ability_name)
	if not anim_data:
		print("❌ [AnimationBridge] No active animation for: ", ability_name)
		return
	
	var config = anim_data.config
	var instance = anim_data.instance
	
	# Skip windup for bullet_rain - go straight to QTE
	if ability_name == "bullet_rain":
		print("🎬 [AnimationBridge] Skipping windup for bullet_rain, ready for QTE immediately")
		animation_ready_for_qte.emit(ability_name)
		return
	
	# Get the AnimationPlayer from the spawned instance
	var animation_player = instance.get_node_or_null(config.animation_player_path)
	if not animation_player:
		print("❌ [AnimationBridge] AnimationPlayer not found at: ", config.animation_player_path)
		return
	
	# Debug the AnimatedSprite2D
	var hero_sprite = instance.get_node_or_null(config.controller_node_path)
	if hero_sprite:
		print("🎬 [AnimationBridge] Hero sprite current animation: ", hero_sprite.animation)
		print("🎬 [AnimationBridge] Hero sprite available animations: ", hero_sprite.sprite_frames.get_animation_names())
		print("🎬 [AnimationBridge] Hero sprite position: ", hero_sprite.global_position)
		print("🎬 [AnimationBridge] Hero sprite scale: ", hero_sprite.scale)
		print("🎬 [AnimationBridge] Hero sprite visible: ", hero_sprite.visible)
	
	# Play windup animation
	animation_player.play(config.windup_animation)
	print("🎬 [AnimationBridge] Playing: ", config.windup_animation)
	
	# Check if animation actually changed
	await get_tree().process_frame
	if hero_sprite:
		print("🎬 [AnimationBridge] Hero sprite animation after play: ", hero_sprite.animation)
		print("🎬 [AnimationBridge] Hero sprite position after play: ", hero_sprite.global_position)
		print("🎬 [AnimationBridge] Hero sprite frame after play: ", hero_sprite.frame)
	
	# Wait for windup to finish, then signal ready for QTE
	await animation_player.animation_finished
	print("🎬 [AnimationBridge] Windup complete, ready for QTE")
	animation_ready_for_qte.emit(ability_name)

func play_result_animation(ability_name: String, qte_result: String):
	print("🎬 [AnimationBridge] Playing result animation for: ", ability_name, " result: ", qte_result)
	
	var anim_data = active_animations.get(ability_name)
	if not anim_data:
		print("❌ [AnimationBridge] No active animation for: ", ability_name)
		return
	
	var config = anim_data.config
	var instance = anim_data.instance
	
	# Get the AnimationPlayer
	var animation_player = instance.get_node_or_null(config.animation_player_path)
	if not animation_player:
		print("❌ [AnimationBridge] AnimationPlayer not found at: ", config.animation_player_path)
		return
	
	# Choose animation based on result
	var animation_name = ""
	if qte_result in ["crit", "normal"]:
		animation_name = config.success_animation
	else:
		animation_name = config.fail_animation
	
	# Play result animation
	animation_player.play(animation_name)
	print("🎬 [AnimationBridge] Playing result: ", animation_name)
	
	# Wait for result animation to finish
	await animation_player.animation_finished
	print("🎬 [AnimationBridge] Result animation complete")
	
	# Clean up
	cleanup_animation(ability_name)
	animation_sequence_complete.emit(ability_name)

func cleanup_animation(ability_name: String):
	print("🎬 [AnimationBridge] Cleaning up: ", ability_name)
	
	var anim_data = active_animations.get(ability_name)
	if anim_data:
		# Restore player idle animation
		if anim_data.get("player_idle_sprite") and anim_data.player_idle_sprite:
			anim_data.player_idle_sprite.visible = true
			print("🎬 [AnimationBridge] Restored player idle animation")
		
		# Clean up animation instance
		if anim_data.instance:
			anim_data.instance.queue_free()
	
	active_animations.erase(ability_name)
	print("🎬 [AnimationBridge] Cleanup complete")

# Helper to add new animation configurations easily
func register_ability_animation(ability_name: String, config: Dictionary):
	animation_library[ability_name] = config
	print("🎬 [AnimationBridge] Registered animation for: ", ability_name)

# Debug helper to print scene tree
func _debug_print_children(node: Node, prefix: String, depth: int):
	if depth > 3:  # Prevent infinite recursion
		return
	
	var info = node.name
	if node is AnimatedSprite2D:
		info += " (AnimatedSprite2D - animation: " + str(node.animation) + ", visible: " + str(node.visible) + ")"
	elif node is AnimationPlayer:
		info += " (AnimationPlayer - current: " + str(node.current_animation) + ")"
	
	print("🔍 " + prefix + info)
	
	for child in node.get_children():
		_debug_print_children(child, prefix + "  ", depth + 1)
