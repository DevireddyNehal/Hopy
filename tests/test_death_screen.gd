extends Node2D

func _ready() -> void:
	print("\n--- TESTING DEATH SCREEN & TIERED ROASTS ---")
	
	var death_scene = load("res://scenes/DeathScreen.tscn")
	assert(death_scene != null, "DeathScreen.tscn must exist")
	var death_screen = death_scene.instantiate()
	add_child(death_screen)
	
	assert(not death_screen.visible, "DeathScreen should start hidden")
	print("✓ DeathScreen initial hidden state verified")
	
	# Test Low tier (< 100)
	GameState.start_game()
	GameState.score = 45
	GameState.best_score = 300
	GameState.end_game()
	
	assert(death_screen.visible, "DeathScreen should be visible after game_over")
	assert(death_screen.score_label.text == "SCORE: 45", "Score label should display 45")
	assert(death_screen.best_label.text == "BEST: 300", "Best label should display 300")
	assert(not death_screen.new_best_label.visible, "New best should be hidden when score < best")
	var low_roasts = death_screen.death_lines.get("low", [])
	var low_matches = false
	for r in low_roasts:
		if death_screen.roast_label.text == "\"" + r + "\"":
			low_matches = true
			break
	assert(low_matches, "Low tier roast should be picked for score < 100")
	print("✓ Low tier roast (< 100) verified: " + death_screen.roast_label.text)
	
	# Test Mid tier (100 - 499)
	GameState.start_game()
	GameState.score = 250
	GameState.best_score = 300
	GameState.end_game()
	var mid_roasts = death_screen.death_lines.get("mid", [])
	var mid_matches = false
	for r in mid_roasts:
		if death_screen.roast_label.text == "\"" + r + "\"":
			mid_matches = true
			break
	assert(mid_matches, "Mid tier roast should be picked for score 100-499")
	print("✓ Mid tier roast (100-499) verified: " + death_screen.roast_label.text)
	
	# Test High tier (500+) and New Best
	GameState.start_game()
	GameState.score = 850
	GameState.best_score = 850
	GameState.end_game()
	var high_roasts = death_screen.death_lines.get("high", [])
	var high_matches = false
	for r in high_roasts:
		if death_screen.roast_label.text == "\"" + r + "\"":
			high_matches = true
			break
	assert(high_matches, "High tier roast should be picked for score >= 500")
	assert(death_screen.new_best_label.visible, "New best badge should be visible")
	print("✓ High tier roast (500+) & New Best badge verified: " + death_screen.roast_label.text)
	
	print("--- DEATH SCREEN TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
