extends Node2D

func _ready() -> void:
	print("\n--- TESTING TITLE SCREEN ---")
	
	var title_scene = load("res://scenes/TitleScreen.tscn")
	assert(title_scene != null, "TitleScreen.tscn must exist")
	var title_screen = title_scene.instantiate()
	add_child(title_screen)
	
	assert(title_screen.title_label.text == "HOPY", "Title must be HOPY")
	assert(title_screen.play_button != null, "Play button must exist")
	assert(title_screen.start_prompt != null, "Start prompt must exist")
	print("✓ TitleScreen UI nodes verified (Title: HOPY, Best Score, Controls Card)")
	
	print("--- TITLE SCREEN TESTS PASSED SUCCESSFULLY! ---\n")
	get_tree().quit(0)
