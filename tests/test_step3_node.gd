extends Node

func _ready() -> void:
	print("--- TESTING STEP 3: SCORE, COMBO, BEST PERSISTENCE & HUD ---")
	
	# 1. Load Main Scene with HUD
	var main_scene = load("res://scenes/Main.tscn")
	assert(main_scene != null, "Main scene must load")
	var main = main_scene.instantiate()
	add_child(main)
	
	var hud = main.get_node("HUD")
	assert(hud != null, "HUD must exist in Main")
	print("✓ HUD initialized in Main scene")
	
	# 2. Test Score update
	GameState.start_game()
	GameState.update_score(150)
	assert(hud.score_label.text == "150", "HUD score label should show updated score")
	print("✓ Live score display verified (150)")
	
	# 3. Test Combo update
	GameState.increment_combo() # combo = 1
	assert(hud.combo_container.visible == false, "Combo container should be hidden at combo <= 1")
	GameState.increment_combo() # combo = 2
	assert(hud.combo_container.visible == true, "Combo container should be visible at combo > 1")
	assert(hud.combo_label.text in ["x2 COMBO!", "×2 COMBO!"], "Combo label should show combo text")
	print("✓ Combo counter & dynamic visibility verified")
	
	# 4. Test Best score persistence to user://best.txt
	GameState.update_score(350)
	GameState.end_game()
	assert(GameState.best_score >= 350, "Best score should be updated to at least 350")
	assert(FileAccess.file_exists(GameState.BEST_SCORE_PATH), "user://best.txt must exist on disk")
	
	# Check file content
	var file = FileAccess.open(GameState.BEST_SCORE_PATH, FileAccess.READ)
	assert(file != null, "best.txt must be readable")
	var saved_text = file.get_as_text().strip_edges()
	file.close()
	assert(int(saved_text) == GameState.best_score, "Saved file content must match GameState.best_score")
	print("✓ Best score file persistence verified (saved " + saved_text + " to user://best.txt)")
	
	print("--- STEP 3 TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
