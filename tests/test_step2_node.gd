extends Node

const PlatformScript = preload("res://scripts/platform.gd")

func _ready() -> void:
	print("--- TESTING STEP 2: PLATFORMS, CAMERA, THORN HAZARD & FALLING DEATH ---")
	
	# 1. Load Main Scene
	GameState.start_game()
	var main_scene = load("res://scenes/Main.tscn")
	assert(main_scene != null, "Main scene must load")
	var main = main_scene.instantiate()
	add_child(main)
	
	var robot = main.get_node("Robot")
	var camera = main.get_node("Camera2D")
	var spawner = main.get_node("Spawner")
	
	assert(robot != null, "Robot must exist in Main")
	assert(camera != null, "Camera2D must exist in Main")
	assert(spawner != null, "Spawner must exist in Main")
	print("✓ Main scene nodes initialized")
	
	# 2. Verify platform spawning gaps
	assert(spawner.active_platforms.size() >= 10, "Spawner must pre-generate at least 10 platforms")
	var prev_y = spawner.active_platforms[0].global_position.y
	for i in range(1, spawner.active_platforms.size()):
		var cur_y = spawner.active_platforms[i].global_position.y
		var gap = prev_y - cur_y
		assert(gap <= 330.0, "Platform vertical gap must not exceed max jump reach (497px). Found gap: " + str(gap))
		prev_y = cur_y
	print("✓ Platform procedural generation verified (all gaps reachable < 330px, apex is 497px)")
	
	# 3. Test Thorn Platform instant death
	var thorn_plat = load("res://scenes/Platform.tscn").instantiate()
	thorn_plat.platform_type = PlatformScript.Type.THORN
	add_child(thorn_plat)
	
	var death_signal = [false]
	GameState.game_over.connect(func(): death_signal[0] = true)
	thorn_plat.on_robot_landed(robot)
	assert(robot.is_dead == true, "Landing on Thorn platform must kill the robot")
	assert(death_signal[0] == true, "Thorn landing must trigger GameState game_over")
	print("✓ Thorn platform instant-death verified")
	
	# 4. Test Camera falling death detection
	# Reset robot for fall test
	robot.is_dead = false
	death_signal[0] = false
	GameState.start_game()
	var half_h = camera.get_viewport_rect().size.y / 2.0
	camera.global_position.y = 0.0
	robot.global_position.y = camera.global_position.y + half_h + 150.0 # Below screen bottom
	camera._physics_process(0.016)
	assert(robot.is_dead == true, "Falling below camera bottom must trigger death")
	print("✓ Falling below camera triggers death verified")
	
	print("--- STEP 2 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
