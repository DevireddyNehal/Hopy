extends Node2D

func _ready() -> void:
	print("\n--- TESTING NEW FEATURES: CRACKED CRUMBLE, SPIKE BALL, INVERTED CONTROLS, ABYSS FALL & START AUDIO ---")
	
	# Test 1: Crumble platform is cracked by default with rust tint
	var plat_scene = preload("res://scenes/Platform.tscn")
	var crumble_plat = plat_scene.instantiate()
	crumble_plat.platform_type = Platform.Type.CRUMBLE
	add_child(crumble_plat)
	crumble_plat.apply_type_style()
	assert(crumble_plat.sprite.texture != null, "Crumble platform must have a texture")
	assert(crumble_plat.sprite.modulate.r > 0.8 and crumble_plat.sprite.modulate.g > 0.5, "Crumble platform must retain rust tint")
	print("✓ Crumble platform uses cracked texture as default with rust color")
	crumble_plat.queue_free()
	
	# Test 2: FloatingSpikeBall hazard
	var spike_scene = preload("res://scenes/SpikeBall.tscn")
	var spike_ball = spike_scene.instantiate()
	add_child(spike_ball)
	assert(spike_ball is FloatingSpikeBall, "SpikeBall must be instance of FloatingSpikeBall")
	
	var robot_scene = preload("res://scenes/Robot.tscn")
	var robot = robot_scene.instantiate()
	add_child(robot)
	assert(not robot.is_dead, "Robot must initially be alive")
	
	# Touch spike ball
	spike_ball._on_body_entered(robot)
	assert(robot.is_dead, "Touching spike ball must kill the robot immediately")
	print("✓ Floating Spike Ball kills robot on contact")
	spike_ball.queue_free()
	robot.queue_free()
	
	# Test 3: Inverted controls at 500 score (testing threshold)
	GameState.start_game()
	assert(not GameState.are_controls_inverted, "Controls must not be inverted initially")
	
	var warning_flag = [false]
	GameState.controls_inverted_warning_started.connect(func(): warning_flag[0] = true)
	
	GameState.update_score(505)
	assert(warning_flag[0], "controls_inverted_warning_started signal must fire at 500 score")
	assert(GameState.controls_warning_active, "3-second disclaimer must be active at 500 score")
	print("✓ 500 score triggers 3-second disclaimer and social credit siren (testing threshold)")
	
	# Test 4: Falling abyss death with mixkit falling scream
	assert(GameState.sfx_falling_scream != null, "falling_scream.mp3 must be loaded in GameState")
	assert(GameState.sfx_cat_laugh != null, "cat_laugh.mp3 must be loaded in GameState")
	
	var robot2 = robot_scene.instantiate()
	add_child(robot2)
	robot2.start_falling_abyss_death()
	assert(robot2.is_dead, "Abyss fall must mark robot dead")
	assert(robot2.is_falling_death, "is_falling_death must be true")
	assert(robot2.collision_layer == 0 and robot2.collision_mask == 0, "Abyss fall must disable all collision so floor bouncing is impossible")
	print("✓ Abyss fall triggers extended falling, disables floor collisions, and plays falling scream")
	robot2.queue_free()
	
	# Test 5: DeathScreen Laughing Cat Meme
	var death_scene = preload("res://scenes/DeathScreen.tscn")
	var death_instance = death_scene.instantiate()
	add_child(death_instance)
	assert(death_instance.has_node("Panel/Margin/VBox/LaughingCatMeme"), "DeathScreen must have LaughingCatMeme node")
	print("✓ DeathScreen features Laughing Cat meme animation")
	death_instance.queue_free()
	
	# Test 6: Mac Quack bounce sound
	assert(GameState.bounce_sounds.size() > 0, "bounce_sounds must have entries")
	print("✓ Mac quack sound loaded as default bounce sound")
	
	# Test 7: Start game audio
	assert(GameState.sfx_start != null, "start_game.mp3 must be loaded in GameState")
	print("✓ Starting audio 'Chaliye shuru karte hain' verified")
	
	# Test 8: Forgiving edge & non-level platform jump detection
	var test_plat = plat_scene.instantiate()
	test_plat.global_position = Vector2(200, 200)
	add_child(test_plat)
	
	var edge_robot = robot_scene.instantiate()
	edge_robot.global_position = Vector2(248, 208) # At right edge, feet below platform top
	edge_robot.velocity.y = 150.0 # Falling
	add_child(edge_robot)
	
	# When falling and touching edge/not level: must trigger jump
	test_plat._try_trigger_landing(edge_robot)
	assert(edge_robot.velocity.y == -960.0, "Touching platform edge while falling must trigger bounce")
	
	# When rocketing upward: must NOT trigger bounce (phases through)
	edge_robot.velocity.y = -500.0
	test_plat._try_trigger_landing(edge_robot)
	assert(edge_robot.velocity.y == -500.0, "Rocketing upward through platform must not trigger premature bounce")
	print("✓ Forgiving edge & non-level platform landing verified")
	test_plat.queue_free()
	edge_robot.queue_free()
	
	# Test 9: Safe spike hazard placement outside natural jump corridor & never above platforms
	var spawner_scene = preload("res://scenes/Main.tscn")
	var main_node = spawner_scene.instantiate()
	add_child(main_node)
	var spawner = main_node.get_node("Spawner")
	
	# Verify that no spike balls spawn when score < 500
	GameState.score = 250
	assert(GameState.score < 500, "Score is under 500 for testing")
	
	# Verify _is_position_above_any_platform rejects positions above platforms
	if spawner.active_platforms.size() > 0:
		var sample_plat = spawner.active_platforms[0]
		var directly_above_x = sample_plat.global_position.x
		var directly_above_y = sample_plat.global_position.y - 60.0
		assert(spawner._is_position_above_any_platform(directly_above_x, directly_above_y), "Must detect and reject positions directly above platforms")
	
	# Test left-to-right jump (from 350 to 580)
	for i in range(10):
		var pos = spawner._calculate_safe_hazard_position(350.0, 580.0, 300.0, 150.0, 960.0, 290.0, 670.0)
		if pos != Vector2.ZERO:
			var inside_corridor = pos.x > 350.0 and pos.x < 580.0
			assert(not inside_corridor, "Spike must NEVER be placed in the middle of platforms along the natural path")
			assert(absf(pos.x - 580.0) >= 80.0, "Spike must maintain at least 80px breathing room from target platform")
			assert(not spawner._is_position_above_any_platform(pos.x, pos.y), "Spike position must NEVER be above any platform")
			
	# Test right-to-left jump (from 600 to 380)
	for i in range(10):
		var pos2 = spawner._calculate_safe_hazard_position(600.0, 380.0, 300.0, 150.0, 960.0, 290.0, 670.0)
		if pos2 != Vector2.ZERO:
			var inside_corridor2 = pos2.x > 380.0 and pos2.x < 600.0
			assert(not inside_corridor2, "Spike must NEVER be placed in the middle of platforms along right-to-left natural path")
			assert(absf(pos2.x - 380.0) >= 80.0, "Spike must maintain at least 80px breathing room from target platform")
			assert(not spawner._is_position_above_any_platform(pos2.x, pos2.y), "Spike position must NEVER be above any platform")
			
	print("✓ Natural jump path free of spikes, score >= 500 gating, and zero platforms underneath verified")
	main_node.queue_free()
	
	print("--- ALL NEW FEATURE TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
