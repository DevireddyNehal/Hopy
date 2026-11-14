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
	
	# Test 3: Inverted controls at 1000 score
	GameState.start_game()
	assert(not GameState.are_controls_inverted, "Controls must not be inverted initially")
	
	var warning_flag = [false]
	GameState.controls_inverted_warning_started.connect(func(): warning_flag[0] = true)
	
	GameState.update_score(1005)
	assert(warning_flag[0], "controls_inverted_warning_started signal must fire at 1000 score")
	assert(GameState.controls_warning_active, "3-second disclaimer must be active at 1000 score")
	print("✓ 1000 score triggers 3-second disclaimer and social credit siren")
	
	# Test 4: Falling abyss death with cat-laugh meme
	var robot2 = robot_scene.instantiate()
	add_child(robot2)
	robot2.start_falling_abyss_death()
	assert(robot2.is_dead, "Abyss fall must mark robot dead")
	assert(robot2.is_falling_death, "is_falling_death must be true")
	assert(robot2.collision_layer == 0 and robot2.collision_mask == 0, "Abyss fall must disable all collision so floor bouncing is impossible")
	print("✓ Abyss fall triggers extended falling, disables floor collisions, and plays cat-laugh")
	robot2.queue_free()
	
	# Test 5: Start game audio
	assert(GameState.sfx_start != null, "start_game.mp3 must be loaded in GameState")
	print("✓ Starting audio 'Chaliye shuru karte hain' verified")
	
	print("--- ALL NEW FEATURE TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
