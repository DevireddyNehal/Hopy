extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var mute_button: Button = %MuteButton

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if resume_button:
		resume_button.pressed.connect(resume_game)
	if restart_button:
		restart_button.pressed.connect(restart_game)
	if mute_button:
		mute_button.pressed.connect(toggle_mute)
		_update_mute_button()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_action"):
		# If game over, don't allow pause
		if not GameState.is_game_active:
			return
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	is_paused = true
	visible = true
	get_tree().paused = true
	GameState.game_paused.emit(true)
	
	# Small scale-in animation
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func resume_game() -> void:
	is_paused = false
	visible = false
	get_tree().paused = false
	GameState.game_paused.emit(false)

func restart_game() -> void:
	resume_game()
	get_tree().reload_current_scene()

func toggle_mute() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	var currently_muted = AudioServer.is_bus_mute(master_idx)
	AudioServer.set_bus_mute(master_idx, not currently_muted)
	_update_mute_button()

func _update_mute_button() -> void:
	if not mute_button:
		return
	var master_idx = AudioServer.get_bus_index("Master")
	var is_muted = AudioServer.is_bus_mute(master_idx)
	if is_muted:
		mute_button.text = "SOUND: MUTED [OFF]"
	else:
		mute_button.text = "SOUND: ON"
