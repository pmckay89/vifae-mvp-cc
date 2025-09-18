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
	},
	"basic_attack_p1": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "attack_windup_p1",
		"success_animation": "attack_finish_p1", 
		"fail_animation": "ninja_hitstun", # Use ninja hitstun for Player1
		"spawn_offset": Vector2(-200, 0) # Left side positioning
	},
	"2x_cut": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "2x_windup",
		"success_animation": "2x_finish", 
		"fail_animation": "ninja_hitstun", # Use ninja hitstun for Player1
		"spawn_offset": Vector2(-200, 0), # Left side positioning
		"sprite_scale": Vector2(2.25, 2.25) # Custom scale for this ability
	},
	"whirlwind": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "ninja_ww_windup",
		"success_animation": "ninja_ww_attack", 
		"fail_animation": "ninja_hitstun", # Use ninja hitstun for Player1
		"spawn_offset": Vector2(-200, 0), # Left side positioning
		"sprite_scale": Vector2(2.25, 2.25) # Custom scale for this ability
	},
	"poison": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "attack_windup_p1", # Use basic attack windup
		"success_animation": "attack_finish_p1", # Use basic attack finish
		"fail_animation": "ninja_hitstun", # Use ninja hitstun for Player1
		"spawn_offset": Vector2(-200, 0), # Left side positioning
		"sprite_scale": Vector2(2.25, 2.25) # Custom scale for this ability
	},
	"ghost_attack": {
		"scene_path": "res://testing animations.tscn",
		"controller_node_path": "HeroRoot/Hero", # The AnimatedSprite2D to control
		"animation_player_path": "HeroRoot/Hero/AnimationPlayer", # The AnimationPlayer
		"windup_animation": "BE_Test1_Windup",
		"success_animation": "BE_Test1_Finish",
		"fail_animation": "ninja_hitstun", # Use ninja hitstun for Player1
		"spawn_offset": Vector2(-200, 0), # Left side positioning
		"sprite_scale": Vector2(2.25, 2.25), # Custom scale for this ability
		"modulate_color": Color.BLACK # Black silhouette effect
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
	
	# Apply custom sprite scale if specified
	if config.has("sprite_scale"):
		var hero_sprite = animation_instance.get_node_or_null(config.controller_node_path)
		if hero_sprite:
			hero_sprite.scale = config.sprite_scale
			print("🎬 [AnimationBridge] Applied custom scale: ", config.sprite_scale)

	# Apply custom modulation if specified (for special effects like Ghost Attack)
	if config.has("modulate_color"):
		var hero_sprite = animation_instance.get_node_or_null(config.controller_node_path)
		if hero_sprite:
			hero_sprite.modulate = config.modulate_color
			print("🎬 [AnimationBridge] Applied custom modulation: ", config.modulate_color)
	
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
	
	# Hide player's idle animation during attack (universal system)
	var player_idle_sprites = []
	if not config.get("skip_idle_hiding", false):
		player_idle_sprites = hide_player_idle_sprites(player_node)
		print("🎬 [AnimationBridge] Hidden ", player_idle_sprites.size(), " idle sprite(s)")
	
	# Store reference
	active_animations[ability_name] = {
		"instance": animation_instance,
		"config": config,
		"player_node": player_node,
		"player_idle_sprites": player_idle_sprites
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
	
	# Debug AnimationPlayer animations
	print("🎬 [AnimationBridge] AnimationPlayer available animations: ", animation_player.get_animation_list())
	
	# Use AnimationPlayer for all abilities (standard system)
	var windup_anim = animation_player.get_animation(config.windup_animation)
	if windup_anim:
		windup_anim.loop_mode = Animation.LOOP_NONE
		print("🔧 [AnimationBridge] Disabled looping for: ", config.windup_animation)

	animation_player.play(config.windup_animation)
	print("🎬 [AnimationBridge] Playing AnimationPlayer: ", config.windup_animation)

	# Wait for windup to finish, then pause and signal ready for QTE
	await animation_player.animation_finished

	# Pause the animation player to freeze on last frame during QTE
	animation_player.pause()
	print("🎬 [AnimationBridge] Windup complete, animation paused for QTE")
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

	# Use AnimationPlayer for all abilities (standard system)
	var result_anim = animation_player.get_animation(animation_name)
	if result_anim:
		result_anim.loop_mode = Animation.LOOP_NONE
		print("🔧 [AnimationBridge] Disabled looping for: ", animation_name)

	# Play result animation (this will resume from paused state)
	animation_player.play(animation_name)
	print("🎬 [AnimationBridge] Playing AnimationPlayer result: ", animation_name)

	# Wait for result animation to finish
	await animation_player.animation_finished

	print("🎬 [AnimationBridge] Result animation complete")
	
	# Return to appropriate idle animation
	print("🔍 [AnimationBridge] Checking return idle for ability: ", ability_name)
	if ability_name in ["basic_attack_p1", "2x_cut", "whirlwind", "poison", "ghost_attack"]:
		# Player1 returns to idle_p1 animation
		animation_player.play("idle_p1")
		print("🎬 [AnimationBridge] Player1 returning to idle_p1")
	elif ability_name == "basic_attack":
		# Player2 returns to appropriate idle - check if idle animation exists
		print("🔍 [AnimationBridge] Player2 basic_attack - checking idle animation")
		if animation_player.has_animation("idle"):
			print("🔍 [AnimationBridge] Playing idle animation for Player2")
			animation_player.play("idle")
			print("🎬 [AnimationBridge] Player2 returning to idle")
		else:
			print("⚠️ [AnimationBridge] No idle animation found for Player2")
	
	# Clean up
	cleanup_animation(ability_name)
	animation_sequence_complete.emit(ability_name)

func cleanup_animation(ability_name: String):
	print("🎬 [AnimationBridge] Cleaning up: ", ability_name)
	
	var anim_data = active_animations.get(ability_name)
	if anim_data:
		# Restore player idle animations
		var idle_sprites = anim_data.get("player_idle_sprites", [])
		for sprite in idle_sprites:
			print("🔍 [AnimationBridge] Trying to restore sprite: ", sprite, " valid: ", is_instance_valid(sprite))
			if is_instance_valid(sprite):
				print("🔍 [AnimationBridge] Restoring sprite: ", sprite.name if sprite.has_method("get") else "unknown")
				sprite.visible = true
			else:
				print("❌ [AnimationBridge] Skipping invalid sprite during restore")
		if idle_sprites.size() > 0:
			print("🎬 [AnimationBridge] Restored ", idle_sprites.size(), " idle sprite(s)")
		
		# Clean up animation instance
		if anim_data.instance:
			anim_data.instance.queue_free()
	
	active_animations.erase(ability_name)
	print("🎬 [AnimationBridge] Cleanup complete")

# Helper to add new animation configurations easily
func register_ability_animation(ability_name: String, config: Dictionary):
	animation_library[ability_name] = config
	print("🎬 [AnimationBridge] Registered animation for: ", ability_name)

# Universal idle sprite hiding system
func hide_player_idle_sprites(player_node: Node2D) -> Array:
	var hidden_sprites = []

	# Common idle sprite node names to check
	var idle_node_names = ["idle", "IdleAnimatedSprite", "Idle", "idle_sprite", "idle_p1"]

	for node_name in idle_node_names:
		var idle_sprite = player_node.get_node_or_null(node_name)
		if is_instance_valid(idle_sprite) and idle_sprite.visible:
			idle_sprite.visible = false
			hidden_sprites.append(idle_sprite)
			print("🎬 [AnimationBridge] Hidden idle sprite: ", node_name)

	return hidden_sprites

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

# Play hitstun animation for damaged players
func play_hitstun_animation(animation_name: String, player_name: String):
	print("🎬 [AnimationBridge] Playing hitstun animation: ", animation_name, " for ", player_name)

	# Load and instantiate animation scene
	var animation_scene = load("res://testing animations.tscn")
	if not animation_scene:
		print("❌ [AnimationBridge] Could not load testing animations scene")
		return

	var animation_instance = animation_scene.instantiate()
	get_tree().current_scene.add_child(animation_instance)

	# Position the animation at spawn position
	animation_instance.global_position = Vector2(0, 0)
	animation_instance.z_index = 100

	# Hide the corresponding player's idle sprite and position HeroRoot
	var player_node = null
	var hero_root = animation_instance.get_node_or_null("HeroRoot")
	if hero_root:
		# Get the player node and hide their idle sprite
		if player_name == "Player1":
			player_node = get_tree().current_scene.get_node_or_null("Player1")
			hero_root.position = Vector2(35, 330)  # Player1's battle position
		elif player_name == "Player2":
			player_node = get_tree().current_scene.get_node_or_null("Player2")
			hero_root.position = Vector2(40, 430)

		# Hide the player's sprites during hitstun
		if player_node:
			if player_name == "Player1":
				var idle_sprite = player_node.get_node_or_null("idle")
				if is_instance_valid(idle_sprite):
					idle_sprite.visible = false
					print("🎬 [AnimationBridge] Hidden Player1 idle sprite during hitstun")
			elif player_name == "Player2":
				# Player2 has multiple sprites that need to be hidden
				var idle_animated = player_node.get_node_or_null("IdleAnimatedSprite")
				var main_sprite = player_node.get_node_or_null("Sprite2D")
				var idle2_sprite = player_node.get_node_or_null("idle2")
				var attack_sprite = player_node.get_node_or_null("attack")

				if is_instance_valid(idle_animated):
					idle_animated.visible = false
					print("🎬 [AnimationBridge] Hidden Player2 IdleAnimatedSprite during hitstun")
				if is_instance_valid(main_sprite):
					main_sprite.visible = false
					print("🎬 [AnimationBridge] Hidden Player2 main Sprite2D during hitstun")
				if is_instance_valid(idle2_sprite):
					idle2_sprite.visible = false
					print("🎬 [AnimationBridge] Hidden Player2 idle2 sprite during hitstun")
				if is_instance_valid(attack_sprite):
					attack_sprite.visible = false
					print("🎬 [AnimationBridge] Hidden Player2 attack sprite during hitstun")

		# Apply scale based on player
		if player_name == "Player1":
			hero_root.scale = Vector2(1.25, 1.25)  # Larger for Player1
		else:
			hero_root.scale = Vector2(1.20, 1.20)  # Larger scale for Player2

	# Get the AnimationPlayer and play the hitstun animation
	var animation_player = animation_instance.get_node_or_null("HeroRoot/Hero/AnimationPlayer")
	if animation_player:
		# Debug: Check what animation is currently playing before we change it
		var current_anim = animation_player.current_animation
		print("🔍 [AnimationBridge] Current animation before play: ", current_anim)

		animation_player.play(animation_name)
		print("🎬 [AnimationBridge] Playing hitstun: ", animation_name)

		# Debug: Confirm what's now playing
		var new_current_anim = animation_player.current_animation
		print("🔍 [AnimationBridge] Current animation after play: ", new_current_anim)

		# Clean up after animation finishes
		animation_player.animation_finished.connect(func(anim_name):
			print("🎬 [AnimationBridge] Hitstun animation finished: ", anim_name)

			# Restore the player's sprites after hitstun
			if player_node:
				if player_name == "Player1":
					var idle_sprite = player_node.get_node_or_null("idle")
					if is_instance_valid(idle_sprite):
						idle_sprite.visible = true
						print("🎬 [AnimationBridge] Restored Player1 idle sprite after hitstun")
				elif player_name == "Player2":
					# Player2 has multiple sprites - restore the main ones
					var idle_animated = player_node.get_node_or_null("IdleAnimatedSprite")
					var main_sprite = player_node.get_node_or_null("Sprite2D")

					if is_instance_valid(idle_animated):
						idle_animated.visible = true
						print("🎬 [AnimationBridge] Restored Player2 IdleAnimatedSprite after hitstun")
					if is_instance_valid(main_sprite):
						main_sprite.visible = true
						print("🎬 [AnimationBridge] Restored Player2 main Sprite2D after hitstun")

					# Note: Don't restore idle2 or attack sprites - they should stay hidden unless specifically needed

			animation_instance.queue_free()
		)
	else:
		print("❌ [AnimationBridge] Could not find AnimationPlayer for hitstun")
		animation_instance.queue_free()
