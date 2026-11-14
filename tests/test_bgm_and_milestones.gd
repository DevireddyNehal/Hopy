extends Node2D

func _ready() -> void:
	print("\n--- TESTING BGM, MILESTONES & PALETTE SHIFTS ---")
	
	# 1. BGM removed verification
	GameState.start_bgm()
	assert(not GameState.is_music_started, "Music should remain disabled per user request")
	print("✓ BGM disabled verified (user request #2: remove background music)")
	
	# 2. Milestones & Palette Shifts
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	add_child(main_scene)
	
	GameState.start_game()
	assert(GameState.color_scheme_index == 0, "Color scheme should start at 0 (Cyber Navy)")
	print("✓ Base color scheme index 0 verified")
	
	# Score to 250 -> palette shift 1
	GameState.update_score(250)
	assert(GameState.color_scheme_index == 1, "Color scheme should shift to 1 at score 250")
	print("✓ Color scheme shift to index 1 verified (Sunset Blaze)")
	
	# Score to 500 -> milestone 500 & palette shift 2
	GameState.update_score(500)
	assert(GameState.reached_500, "500 milestone should be marked reached")
	assert(GameState.color_scheme_index == 2, "Color scheme should shift to 2 at score 500")
	var hud = main_scene.get_node("HUD")
	assert(hud.milestone_banner.visible, "Milestone banner should appear in HUD")
	assert("500" in hud.milestone_label.text, "Milestone banner should display 500")
	print("✓ 500 points milestone & callout banner verified: " + hud.milestone_label.text)
	
	# Score to 1000 -> milestone 1000 & palette shift 4
	GameState.update_score(1000)
	assert(GameState.reached_1000, "1000 milestone should be marked reached")
	assert(GameState.color_scheme_index == 4, "Color scheme should shift to 4 (Hyperdrive)")
	assert("1000" in hud.milestone_label.text, "Milestone banner should display 1000")
	print("✓ 1000 points milestone & callout banner verified: " + hud.milestone_label.text)
	
	print("--- BGM, MILESTONES & PALETTE TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
