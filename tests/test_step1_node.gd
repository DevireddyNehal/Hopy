extends Node

func _ready() -> void:
	print("--- TESTING STEP 1: ROBOT & STEERING ---")
	
	# Load Robot scene
	var robot_scene = load("res://scenes/Robot.tscn")
	assert(robot_scene != null, "Robot scene must load successfully")
	var robot = robot_scene.instantiate()
	add_child(robot)
	
	# 1. Test Initial Properties
	assert(robot.gravity == 1400.0, "Gravity should be 1400.0")
	assert(robot.steer_speed == 650.0, "Steer speed should be 650.0")
	assert(robot.bounce_velocity == -900.0, "Bounce velocity should be -900.0")
	print("✓ Robot properties verified (Gravity 1400, Speed 650, Bounce -900)")
	
	# 2. Test Bounce & Combo
	var initial_combo = GameState.combo
	robot.bounce()
	assert(robot.velocity.y == -900.0, "Bounce must set velocity.y to bounce_velocity (-900.0)")
	assert(GameState.combo == initial_combo + 1, "Bounce must increment GameState combo")
	print("✓ Robot bounce sets vertical velocity and increments combo")
	
	# 3. Test Screen Wrapping
	robot.position.x = -20.0
	robot._physics_process(0.016)
	assert(robot.position.x > 1100.0, "Exiting left edge must wrap to right edge")
	
	var screen_w = robot.get_viewport_rect().size.x
	robot.position.x = screen_w + 30.0
	robot._physics_process(0.016)
	assert(robot.position.x < 50.0, "Exiting right edge must wrap to left edge")
	print("✓ Screen wrapping left and right verified")
	
	print("--- STEP 1 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
