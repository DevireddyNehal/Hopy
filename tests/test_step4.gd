extends Node2D

func _ready() -> void:
	print("\n--- TESTING STEP 4: WORDLESS LANDING MICRO-EFFECTS ---")
	
	var effects_scene = load("res://scenes/Effects.tscn")
	assert(effects_scene != null, "Effects.tscn must exist")
	var effects = effects_scene.instantiate()
	add_child(effects)
	
	var dummy_robot_visual = Node2D.new()
	add_child(dummy_robot_visual)
	effects.bind_character(dummy_robot_visual)
	
	# 1. Sparkle burst
	effects.spawn_sparkle_burst(Vector2(100, 100), 10)
	assert(effects._active.size() == 10, "Should have spawned 10 sparkle particles")
	print("✓ Sparkle burst spawning verified (10 particles)")
	
	# 2. Confetti puff
	effects.spawn_confetti(Vector2(200, 200), 20)
	assert(effects._active.size() == 30, "Should have spawned 20 confetti particles")
	print("✓ Confetti puff verified (20 particles)")
	
	# 3. Pixel emoji
	effects.spawn_pixel_emoji(Vector2(300, 300), 5)
	assert(effects._active.size() == 35, "Should have spawned 5 pixel emoji particles")
	print("✓ Pixel emoji shapes verified (5 particles)")
	
	# 4. Shatter
	effects.spawn_shatter(Vector2(400, 400), 8)
	assert(effects._active.size() == 43, "Should have spawned 8 shatter particles")
	print("✓ Shatter shards verified (8 particles)")
	
	# 5. Character pulse & flip tween
	effects.pulse_character()
	assert(effects._pulse_tween != null and effects._pulse_tween.is_valid(), "Pulse tween should be active")
	effects.flip_character(0.2)
	assert(effects._flip_tween != null and effects._flip_tween.is_valid(), "Flip tween should be active")
	print("✓ Character pulse & 360 flip tweens verified")
	
	# 6. Screen flash
	effects.flash_screen(Color(1, 0, 0, 0.5), 0.2)
	assert(effects._flash_tween != null and effects._flash_tween.is_valid(), "Flash tween should be active")
	print("✓ Screen color flash verified")
	
	# 7. Global GameState trigger API
	GameState.trigger_effect(&"sparkle", Vector2(500, 500))
	assert(effects._active.size() > 43, "GameState.trigger_effect should spawn sparkle particles")
	print("✓ GameState decoupled signal trigger verified")
	
	# 8. Clear all
	effects.clear_all()
	assert(effects._active.is_empty(), "Clear all should return particles to pool")
	print("✓ Particle pool recycling verified")
	
	print("--- STEP 4 TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
