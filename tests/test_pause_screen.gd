extends Node2D

func _ready() -> void:
	print("\n--- TESTING PAUSE SCREEN & AUDIO CONTROLS ---")
	
	var pause_scene = load("res://scenes/PauseScreen.tscn")
	assert(pause_scene != null, "PauseScreen.tscn must exist")
	var pause_screen = pause_scene.instantiate()
	add_child(pause_screen)
	
	assert(not pause_screen.visible, "PauseScreen should start hidden")
	assert(not get_tree().paused, "Tree should start unpaused")
	print("✓ Initial unpaused state verified")
	
	# Test pause
	GameState.is_game_active = true
	pause_screen.pause_game()
	assert(pause_screen.visible, "PauseScreen should be visible when paused")
	assert(get_tree().paused, "Scene tree should be paused")
	print("✓ Pause activation verified")
	
	# Test mute toggle
	var master_bus = AudioServer.get_bus_index("Master")
	var was_muted = AudioServer.is_bus_mute(master_bus)
	pause_screen.toggle_mute()
	assert(AudioServer.is_bus_mute(master_bus) != was_muted, "Audio bus mute state should flip")
	# Restore
	pause_screen.toggle_mute()
	assert(AudioServer.is_bus_mute(master_bus) == was_muted, "Audio bus mute state restored")
	print("✓ Master audio mute toggle verified")
	
	# Test resume
	pause_screen.resume_game()
	assert(not pause_screen.visible, "PauseScreen should be hidden when resumed")
	assert(not get_tree().paused, "Scene tree should be unpaused")
	print("✓ Resume verified")
	
	print("--- PAUSE SCREEN TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
