extends Control

@onready var title_label: Label = %TitleLabel
@onready var best_label: Label = %BestLabel
@onready var start_prompt: Label = %StartPrompt
@onready var play_button: Button = %PlayButton
@onready var control_mode_button: Button = %ControlModeButton if has_node("%ControlModeButton") else null
@onready var controls_info: Label = %ControlsInfo if has_node("%ControlsInfo") else null

var is_starting: bool = false

func _ready() -> void:
	GameState.load_best_score()
	GameState.load_control_mode()
	GameState.control_mode_changed.connect(_update_control_mode_display)
	_update_control_mode_display(GameState.control_mode)
	
	if control_mode_button:
		control_mode_button.pressed.connect(func(): GameState.cycle_control_mode())
	if best_label:
		if GameState.best_score > 0:
			best_label.text = "BEST RECORD: " + str(GameState.best_score)
			best_label.visible = true
		else:
			best_label.text = "CAN YOU REACH 500 PTS?"
			best_label.visible = true
			
	if play_button:
		play_button.pressed.connect(_start_game)
		
	# Floating animation for title
	if title_label:
		var orig_y = title_label.position.y
		var tween = create_tween().set_loops()
		tween.tween_property(title_label, "position:y", orig_y - 8.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(title_label, "position:y", orig_y + 8.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Pulsing animation for prompt
	if start_prompt:
		var p_tween = create_tween().set_loops()
		p_tween.tween_property(start_prompt, "modulate:a", 0.3, 0.7)
		p_tween.tween_property(start_prompt, "modulate:a", 1.0, 0.7)

func _input(event: InputEvent) -> void:
	if is_starting:
		return
	if event.is_action_pressed("start_action") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		_start_game()

func _start_game() -> void:
	if is_starting:
		return
	is_starting = true
	# Ensure vertical portrait orientation and enter fullscreen on mobile platforms
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Play starting meme audio unlock (Chaliye shuru karte hain!)
	GameState.play_start_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _update_control_mode_display(mode: int) -> void:
	var mode_name = GameState.get_control_mode_name(mode)
	if control_mode_button:
		control_mode_button.text = "MOBILE MODE: " + mode_name
	if controls_info:
		controls_info.text = "PC: [A][D]/[ARROWS] | MOBILE: " + mode_name
