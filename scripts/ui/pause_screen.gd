extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var control_mode_button: Button = %ControlModeButton if has_node("%ControlModeButton") else null
@onready var open_tab_button: Button = %OpenTabButton if has_node("%OpenTabButton") else null
@onready var mute_button: Button = %MuteButton

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	GameState.pause_requested.connect(func():
		if not GameState.is_game_active:
			return
		if is_paused:
			resume_game()
		else:
			pause_game()
	)
	
	GameState.control_mode_changed.connect(_update_control_mode_button)
	
	if resume_button:
		resume_button.pressed.connect(resume_game)
	if restart_button:
		restart_button.pressed.connect(restart_game)
	if control_mode_button:
		control_mode_button.pressed.connect(func(): GameState.cycle_control_mode())
		_update_control_mode_button(GameState.control_mode)
	if open_tab_button:
		open_tab_button.pressed.connect(func():
			if OS.has_feature("web"):
				JavaScriptBridge.eval("window.open(window.location.href, '_blank')", true)
		)
	if mute_button:
		mute_button.pressed.connect(toggle_mute)
		_update_mute_button()

func _update_control_mode_button(mode: int) -> void:
	if not control_mode_button:
		return
	control_mode_button.text = "CONTROL: " + GameState.get_control_mode_name(mode)
	if open_tab_button:
		var show_tab_btn = false
		if mode == GameState.ControlMode.GYRO and OS.has_feature("web"):
			var is_iframe = JavaScriptBridge.eval("window.hopyIsIframe ? window.hopyIsIframe() : false", true)
			if is_iframe == true:
				show_tab_btn = true
		open_tab_button.visible = show_tab_btn

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
	_update_control_mode_button(GameState.control_mode)
	
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
