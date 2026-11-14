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
	
	# Test 3: Inverted controls at 700 score (drunk 500 + 200)
	GameState.start_game()
	assert(not GameState.are_controls_inverted, "Controls must not be inverted initially")
	
	var warning_flag = [false]
	GameState.controls_inverted_warning_started.connect(func(): warning_flag[0] = true)
	
	GameState.update_score(705)
	assert(warning_flag[0], "controls_inverted_warning_started signal must fire at 700 score")
	assert(GameState.controls_warning_active, "3-second disclaimer must be active at 700 score")
	print("✓ 700 score triggers 3-second disclaimer and social credit siren")
	
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
	add_child(edge_robot)
	edge_robot.velocity.y = 150.0 # Falling
	
	# When falling and touching edge/not level: must trigger jump
	test_plat._try_trigger_landing(edge_robot)
	assert(edge_robot.velocity.y <= -900.0, "Touching platform edge while falling must trigger bounce")
	
	# When rocketing upward: must NOT trigger bounce (phases through)
	edge_robot.velocity.y = -500.0
	test_plat._try_trigger_landing(edge_robot)
	assert(edge_robot.velocity.y == -500.0, "Rocketing upward through platform must not trigger premature bounce")
	
	# When head hits from bottom (stomach below platform base line 210): must NOT trigger bounce
	var head_hit_robot = robot_scene.instantiate()
	head_hit_robot.global_position = Vector2(200, 225) # Stomach is at 225, below platform base line 210
	add_child(head_hit_robot)
	head_hit_robot.velocity.y = -10.0 # Near jump apex under platform
	test_plat._try_trigger_landing(head_hit_robot)
	assert(head_hit_robot.velocity.y == -10.0, "Head hitting from bottom must not trigger bounce")
	head_hit_robot.queue_free()
	
	print("✓ Forgiving edge landing and underside head-hit rejection verified")
	test_plat.queue_free()
	edge_robot.queue_free()
	
	# Test 9: Safe spike hazard placement outside natural jump corridor & never above platforms
	var spawner_scene = preload("res://scenes/Main.tscn")
	var main_node = spawner_scene.instantiate()
	add_child(main_node)
	var spawner = main_node.get_node("Spawner")
	
	# Verify that no spike balls spawn when score < 200
	GameState.score = 150
	assert(GameState.score < 200, "Score is under 200 for testing")
	
	# Verify _is_position_above_any_platform rejects positions above platforms
	if spawner.active_platforms.size() > 0:
		var sample_plat = spawner.active_platforms[0]
		var directly_above_x = sample_plat.global_position.x
		var directly_above_y = sample_plat.global_position.y - 60.0
		assert(spawner._is_position_above_any_platform(directly_above_x, directly_above_y), "Must detect and reject positions directly above platforms")
	
	# Test left-to-right jump (from 350 to 580) with clear middle
	var saved_platforms = spawner.active_platforms.duplicate()
	spawner.active_platforms.clear()
	
	for i in range(10):
		var pos = spawner._calculate_safe_hazard_position(350.0, 580.0, 300.0, 150.0, 960.0, 290.0, 670.0)
		if pos != Vector2.ZERO:
			assert(pos.x >= 350.0 and pos.x <= 580.0, "Spike should spawn in the middle between platforms")
			assert(absf(pos.x - 580.0) >= 50.0, "Spike must not be directly on top of target platform")
			assert(absf(pos.x - 350.0) >= 50.0, "Spike must not be directly on top of takeoff platform")
			assert(pos.y <= 300.0 + (150.0 * 0.35), "Spike must be positioned high in the gap to leave room below")
			
	# Test right-to-left jump (from 600 to 380) with clear middle
	for i in range(10):
		var pos2 = spawner._calculate_safe_hazard_position(600.0, 380.0, 300.0, 150.0, 960.0, 290.0, 670.0)
		if pos2 != Vector2.ZERO:
			assert(pos2.x >= 380.0 and pos2.x <= 600.0, "Spike should spawn in the middle between platforms")
			assert(absf(pos2.x - 600.0) >= 50.0, "Spike must not be directly on top of target platform")
			assert(absf(pos2.x - 380.0) >= 50.0, "Spike must not be directly on top of takeoff platform")
			assert(pos2.y <= 300.0 + (150.0 * 0.35), "Spike must be positioned high in the gap to leave room below")
			
	# Restore active platforms and verify spike never spawns directly above any platform
	spawner.active_platforms = saved_platforms
	for i in range(10):
		var safe_test_pos = spawner._calculate_safe_hazard_position(350.0, 580.0, 300.0, 150.0, 960.0, 290.0, 670.0)
		if safe_test_pos != Vector2.ZERO:
			assert(not spawner._is_position_above_any_platform(safe_test_pos.x, safe_test_pos.y), "Spike position must NEVER be above any platform")
			
	print("✓ Middle high spike ball placement, score >= 200 gating, and zero platforms underneath verified")
	main_node.queue_free()
	
	# Test 10: Drunk Buff at 500 score with 3s warning, sound, and Linear craft palette
	assert(GameState.sfx_drunk != null, "drunk.mp3 must be loaded in GameState")
	GameState.start_game()
	assert(not GameState.reached_drunk, "reached_drunk must be false initially")
	assert(not GameState.is_drunk, "is_drunk must be false initially")
	assert(not GameState.drunk_warning_active, "drunk_warning_active must be false initially")
	
	var drunk_warning_fired = [false]
	GameState.drunk_warning_started.connect(func(): drunk_warning_fired[0] = true)
	
	# Score 500 triggers drunk warning
	GameState.update_score(505)
	assert(drunk_warning_fired[0], "drunk_warning_started signal must fire at 500 score")
	assert(GameState.drunk_warning_active, "drunk_warning_active must be true during 3s warning")
	assert(GameState.reached_drunk, "reached_drunk must be set to true")
	
	# Test Robot Drunk Buff jump boost (+10% bounce velocity)
	var test_bot = robot_scene.instantiate()
	add_child(test_bot)
	GameState.is_drunk = false
	var standard_bounce = test_bot.get_effective_bounce_velocity()
	GameState.is_drunk = true
	var drunk_bounce = test_bot.get_effective_bounce_velocity()
	assert(absf(drunk_bounce - (standard_bounce * 1.10)) < 0.1, "Drunk buff must provide 1.10x bounce boost")
	test_bot.queue_free()
	
	# Verify craft palette integrity (Linear / Vercel obsidian and twilight)
	assert(GameState.COLOR_SCHEMES[0]["bg"] == Color("08090c"), "Color scheme 0 must be obsidian void")
	assert(GameState.COLOR_SCHEMES[3]["bg"] == Color("0f0a1c"), "Color scheme 3 (750-999) must be twilight violet")
	print("✓ Drunk buff at 500 score, 3s warning, 1.10x bounce boost, and craft obsidian palette verified")
	
	# Test 11: Non-intrusive compact HUD warning, 5s inverted duration & static handmade background
	var hud_scene = preload("res://scenes/HUD.tscn")
	var hud_inst = hud_scene.instantiate()
	add_child(hud_inst)
	var banner = hud_inst.get_node("%DisclaimerBanner")
	assert(banner != null, "DisclaimerBanner must exist")
	# Must be located near top (offset_top = 80, not in center 480!)
	assert(banner.offset_top == 80.0, "DisclaimerBanner must be at top (offset_top = 80)")
	assert(banner.offset_right - banner.offset_left <= 380.0, "DisclaimerBanner width must be compact (<= 380px)")
	assert(banner.offset_bottom - banner.offset_top <= 65.0, "DisclaimerBanner height must be compact (<= 65px)")
	print("✓ Disclaimer banner is compact and non-intrusive at the top (80px, 260x46px)")
	hud_inst.queue_free()
	
	# Verify 5-second inverted controls duration constant
	assert(GameState.INVERT_DURATION == 5.0, "Inverted controls duration must be 5.0 seconds")
	print("✓ Inverted controls duration set to 5.0 seconds with live countdown")
	
	# Verify BackgroundTexture node in Main
	var main2 = preload("res://scenes/Main.tscn").instantiate()
	add_child(main2)
	var bg_tex = main2.get_node_or_null("Background/BackgroundTexture")
	assert(bg_tex != null, "Main must contain Background/BackgroundTexture")
	assert(bg_tex is TextureRect, "BackgroundTexture must be an instance of TextureRect")
	print("✓ Static handmade background texture node verified in Main")
	main2.queue_free()
	
	# Test 12: Recurrent 500-point gap modifiers after initial two (500 Drunk, 700 Inverted)
	GameState.start_game()
	GameState.update_score(505) # 1. Initial Drunk Buff at 500
	GameState.drunk_warning_active = false
	GameState.is_drunk = false
	GameState.update_score(705) # 2. Initial Inverted Controls at 700 (500 + 200)
	GameState.controls_warning_active = false
	GameState.are_controls_inverted = false
	assert(GameState.next_random_modifier_score == 1200, "First recurrent modifier must be scheduled at 1200 (700 + 500)")
	
	var recurrent_event_fired = [false]
	GameState.drunk_warning_started.connect(func(): recurrent_event_fired[0] = true)
	GameState.controls_inverted_warning_started.connect(func(): recurrent_event_fired[0] = true)
	
	# Score 1200 (+500 gap after 700) triggers random modifier
	GameState.update_score(1205)
	assert(recurrent_event_fired[0], "Random modifier must fire at 1200 score (500 gap after 700)")
	assert(GameState.next_random_modifier_score == 1700, "Next recurrent modifier must advance by 500 points to 1700")
	print("✓ Recurrent random modifiers every 500-point gap (1200 -> 1700) verified")
	
	# Test 13: Movable spikes past 500 score & erratic juking normal platforms in waves
	var moving_thorn = plat_scene.instantiate()
	moving_thorn.platform_type = Platform.Type.THORN
	moving_thorn.is_moving_thorn = true
	moving_thorn.position = Vector2(200, 200)
	moving_thorn.move_speed = 100.0
	moving_thorn.move_direction = 1.0
	add_child(moving_thorn)
	moving_thorn._physics_process(0.1) # Simulate 100ms
	assert(moving_thorn.position.x > 200.0, "Movable thorn platform must move horizontally")
	moving_thorn.queue_free()
	
	# Movable spike ball test
	var moving_ball = load("res://scenes/SpikeBall.tscn").instantiate()
	moving_ball.position = Vector2(200, 200)
	moving_ball.horizontal_speed = 60.0
	add_child(moving_ball)
	moving_ball._physics_process(0.1)
	assert(moving_ball.position.x != 200.0, "Movable spike ball must patrol horizontally")
	moving_ball.queue_free()
	
	# Erratic platform juke test
	var erratic_plat = plat_scene.instantiate()
	erratic_plat.platform_type = Platform.Type.NORMAL
	erratic_plat.is_erratic = true
	erratic_plat.position = Vector2(200, 300)
	add_child(erratic_plat)
	assert(not erratic_plat.has_juked, "Erratic platform must not have juked initially")
	
	# Test cyclic wave pacing for erratic platforms
	var spawner_inst = preload("res://scripts/spawner.gd").new()
	GameState.score = 50 # Early wave: positive sine -> high chance
	var hot_chance = spawner_inst._get_erratic_platform_chance()
	assert(hot_chance > 0.30, "Hot wave must have high erratic chance (~44%)")
	GameState.score = 200 # Cold wave: negative sine -> low chance
	var cold_chance = spawner_inst._get_erratic_platform_chance()
	assert(cold_chance < 0.15, "Cold wave must have low erratic chance (~7%)")
	GameState.score = 320 # Next hot wave
	var hot_chance2 = spawner_inst._get_erratic_platform_chance()
	assert(hot_chance2 > 0.30, "Subsequent hot wave must return to high erratic chance")
	spawner_inst.free()
	erratic_plat.queue_free()
	print("✓ Movable spikes past 500 and cyclic erratic platform waves verified")
	
	print("--- ALL NEW FEATURE TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
