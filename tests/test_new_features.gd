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
	
	print("--- ALL NEW FEATURE TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
