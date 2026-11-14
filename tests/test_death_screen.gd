extends Node2D

func _ready() -> void:
	print("\n--- TESTING DEATH SCREEN & TIERED ROASTS ---")
	
	var death_scene = load("res://scenes/DeathScreen.tscn")
	assert(death_scene != null, "DeathScreen.tscn must exist")
	var death_screen = death_scene.instantiate()
	add_child(death_screen)
	
	assert(not death_screen.visible, "DeathScreen should start hidden")
	print("✓ DeathScreen initial hidden state verified")
	
	# Test Low tier (< 500)
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
	assert(low_matches, "Low tier roast should be picked for score < 500")
	print("✓ Low tier roast (< 500) verified: " + death_screen.roast_label.text)
	
	# Test Mid tier (500 - 1499: low-middle score, no praise)
	GameState.start_game()
	GameState.score = 650
	GameState.best_score = 1200
	GameState.end_game()
	var mid_roasts = death_screen.death_lines.get("mid", [])
	var mid_matches = false
	for r in mid_roasts:
		if death_screen.roast_label.text == "\"" + r + "\"":
			mid_matches = true
			break
	assert(mid_matches, "Mid tier roast should be picked for score 500-1499")
	print("✓ Mid tier roast (500-1499) verified: " + death_screen.roast_label.text)
	
	# Test High tier (1500+: praise unlocked) and New Best
	GameState.start_game()
	GameState.score = 1650
	GameState.best_score = 1650
	GameState.end_game()
	var high_roasts = death_screen.death_lines.get("high", [])
	var high_matches = false
	for r in high_roasts:
		if death_screen.roast_label.text == "\"" + r + "\"":
			high_matches = true
			break
	assert(high_matches, "High tier roast should be picked for score >= 1500")
	assert(death_screen.new_best_label.visible, "New best badge should be visible")
	print("✓ High tier roast (1500+) & New Best badge verified: " + death_screen.roast_label.text)
	
	print("--- DEATH SCREEN TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
