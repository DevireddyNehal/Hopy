extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var score_label: Label = %ScoreLabel
@onready var best_label: Label = %BestLabel
@onready var new_best_label: Label = %NewBestLabel
@onready var roast_label: Label = %RoastLabel
@onready var restart_button: Button = %RestartButton

var death_lines: Dictionary = {
	"low": [
		"It's just a game, bro. Can't be that hard.",
		"Bro didn't even try.",
		"Gravity: 1, You: 0."
	],
	"mid": [
		"Skill issue.",
		"Bro fell off.",
		"Almost cooked, but burned.",
		"L + ratio + fell down."
	],
	"high": [
		"Okay, not bad. Touch grass anyway.",
		"Certified hopper.",
		"You were cooking till the slip."
	]
}

var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_death_lines()
	
	if restart_button:
		restart_button.pressed.connect(_restart)
		
	if GameState:
		GameState.game_over.connect(_on_game_over)

func _load_death_lines() -> void:
	if FileAccess.file_exists("res://data/death_lines.json"):
		var f = FileAccess.open("res://data/death_lines.json", FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				death_lines = json.data
			f.close()

func _on_game_over() -> void:
	is_active = true
	visible = true
	
	# Play the cat laugh meme at the game over screen!
	GameState.play_cat_laugh()
	
	var final_score = GameState.score
	var best_score = GameState.best_score
	var is_new_best = (final_score >= best_score and final_score > 0)
	
	score_label.text = "SCORE: " + str(final_score)
	best_label.text = "BEST: " + str(best_score)
	new_best_label.visible = is_new_best
	
	# Pick tiered roast
	var tier_key = "mid"
	if final_score < 100:
		tier_key = "low"
	elif final_score >= 500:
		tier_key = "high"
		
	var pool = death_lines.get(tier_key, ["Skill issue."])
	if pool.size() > 0:
		roast_label.text = "\"" + pool[randi() % pool.size()] + "\""
	else:
		roast_label.text = "\"Skill issue.\""
		
	# Snappy pop-in animation
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("start_action") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		_restart()

func _restart() -> void:
	is_active = false
	visible = false
	get_tree().paused = false
	GameState.play_start_game()
	get_tree().reload_current_scene()
