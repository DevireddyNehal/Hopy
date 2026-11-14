extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal best_score_changed(new_best: int)
signal color_scheme_changed(scheme_index: int)
signal milestone_reached(points: int)
signal game_started
signal game_over
signal game_paused(is_paused: bool)
signal effect_requested(effect_name: StringName, extra_data: Variant)

var score: int = 0
var combo: int = 0
var best_score: int = 0
var color_scheme_index: int = 0

var reached_500: bool = false
var reached_1000: bool = false
const INVERT_CONTROLS_THRESHOLD: int = 500 # TEMPORARY: Set to 500 for testing per user request (revert to 1000 later)
var reached_invert_controls: bool = false
var is_game_active: bool = false

const BEST_SCORE_PATH: String = "user://best.txt"

# Color schemes: [Background color, Primary accent, Secondary accent]
const COLOR_SCHEMES = [
	{"bg": Color("0f1423"), "accent1": Color("ff2a85"), "accent2": Color("00f0ff")}, # 0-249: Cyber Navy
	{"bg": Color("2b0914"), "accent1": Color("ff5722"), "accent2": Color("ffb300")}, # 250-499: Sunset Blaze
	{"bg": Color("0b1d16"), "accent1": Color("39ff14"), "accent2": Color("00e5ff")}, # 500-749: Neon Acid
	{"bg": Color("1a092b"), "accent1": Color("d500f9"), "accent2": Color("ffff00")}, # 750-999: Royal Synth
	{"bg": Color("050510"), "accent1": Color("ff007f"), "accent2": Color("76ff03")}  # 1000+: Hyperdrive
]

signal meme_triggered(meme_text: String)
signal controls_inverted_warning_started()
signal controls_inverted()

var sfx_bounce: AudioStream
var sfx_rainbow: AudioStream
var sfx_meme: AudioStream
var sfx_start: AudioStream
var sfx_social_credit: AudioStream
var sfx_cat_laugh: AudioStream
var sfx_falling_scream: AudioStream
var are_controls_inverted: bool = false
var controls_warning_active: bool = false
var meme_list: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_load_audio_and_data()
	load_best_score()

var bounce_sounds: Array[AudioStream] = []

func _load_audio_and_data() -> void:
	bounce_sounds.clear()
	# Sound 0: Mac Quack sound (user request: replace default bounce with mac quack)
	if ResourceLoader.exists("res://assets/audio/mac_quack.mp3"):
		var s_quack = load("res://assets/audio/mac_quack.mp3")
		bounce_sounds.append(s_quack)
		sfx_bounce = s_quack
	elif ResourceLoader.exists("res://assets/audio/default_bounce.wav"):
		var s_default = load("res://assets/audio/default_bounce.wav")
		bounce_sounds.append(s_default)
		sfx_bounce = s_default
	elif ResourceLoader.exists("res://assets/audio/bounce.wav"):
		var s_boing = load("res://assets/audio/bounce.wav")
		bounce_sounds.append(s_boing)
		sfx_bounce = s_boing
		
	# Sound 1: Michael Jackson "Hee-Hee!"
	if ResourceLoader.exists("res://assets/audio/hee_hee.mp3"):
		var s_mj = load("res://assets/audio/hee_hee.mp3")
		bounce_sounds.append(s_mj)
		sfx_rainbow = s_mj
	elif ResourceLoader.exists("res://assets/audio/rainbow.mp3"):
		var s_mj = load("res://assets/audio/rainbow.mp3")
		bounce_sounds.append(s_mj)
		sfx_rainbow = s_mj
		
	# Sound 2: Meme "Aaye!"
	if ResourceLoader.exists("res://assets/audio/aaye.mp3"):
		var s_aaye = load("res://assets/audio/aaye.mp3")
		bounce_sounds.append(s_aaye)
		sfx_meme = s_aaye
	elif ResourceLoader.exists("res://assets/audio/meme.mp3"):
		var s_aaye = load("res://assets/audio/meme.mp3")
		bounce_sounds.append(s_aaye)
		sfx_meme = s_aaye
		
	# Fallback default
	if bounce_sounds.size() > 0 and not sfx_bounce:
		sfx_bounce = bounce_sounds[0]
		
	# Start game sound (Chaliye shuru karte hain!)
	if ResourceLoader.exists("res://assets/audio/start_game.mp3"):
		sfx_start = load("res://assets/audio/start_game.mp3")
		
	# Social credit siren sound (-999 Social Credit)
	if ResourceLoader.exists("res://assets/audio/social_credit_siren.mp3"):
		sfx_social_credit = load("res://assets/audio/social_credit_siren.mp3")
		
	# Cat laugh meme sound
	if ResourceLoader.exists("res://assets/audio/cat_laugh.mp3"):
		sfx_cat_laugh = load("res://assets/audio/cat_laugh.mp3")
		
	# Mixkit falling male scream 391
	if ResourceLoader.exists("res://assets/audio/falling_scream.mp3"):
		sfx_falling_scream = load("res://assets/audio/falling_scream.mp3")
		
	# Load memes
	if FileAccess.file_exists("res://data/meme_text.json"):
		var f = FileAccess.open("res://data/meme_text.json", FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Array:
				meme_list = json.data
			f.close()
	_setup_sfx_pool()

var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_index: int = 0
const SFX_POOL_SIZE: int = 6

func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)

func _get_sfx_player() -> AudioStreamPlayer:
	if sfx_pool.is_empty():
		_setup_sfx_pool()
	var p = sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % sfx_pool.size()
	return p

func play_bounce() -> void:
	if bounce_sounds.is_empty():
		return
		
	# 1. Base sound shifts every 100 points (0-99: Hee-Hee, 100-199: Aaye, 200-299: Boing)
	var sound_tier = int(score / 100) % bounce_sounds.size()
	var chosen_stream: AudioStream = bounce_sounds[sound_tier]
	
	# 2. Random Surprise: 22% chance to drop in a random sound from the other sounds!
	if randf() < 0.22 and bounce_sounds.size() > 1:
		chosen_stream = bounce_sounds[randi() % bounce_sounds.size()]
		
	var p = _get_sfx_player()
	p.stream = chosen_stream
	# Delayed pitch escalation: only increase pitch every 3 combos
	var pitch_step = int(combo / 3)
	p.pitch_scale = clampf(1.0 + (pitch_step * 0.07), 0.95, 1.85)
	p.play()

func play_rainbow() -> void:
	if not sfx_rainbow:
		return
	var p = _get_sfx_player()
	p.stream = sfx_rainbow
	p.pitch_scale = 1.35
	p.play()

func play_meme() -> void:
	if not sfx_meme:
		return
	var p = _get_sfx_player()
	p.stream = sfx_meme
	p.pitch_scale = 1.0
	p.play()

func play_start_game() -> void:
	if sfx_start:
		var p = _get_sfx_player()
		p.stream = sfx_start
		p.pitch_scale = 1.0
		p.play()
	else:
		play_bounce()

func play_social_credit() -> void:
	if not sfx_social_credit:
		return
	var p = _get_sfx_player()
	p.stream = sfx_social_credit
	p.pitch_scale = 1.0
	p.play()

func play_cat_laugh() -> void:
	if not sfx_cat_laugh:
		return
	var p = _get_sfx_player()
	p.stream = sfx_cat_laugh
	p.pitch_scale = 1.0
	p.play()

func play_falling_scream() -> void:
	if not sfx_falling_scream:
		return
	var p = _get_sfx_player()
	p.stream = sfx_falling_scream
	p.pitch_scale = 1.0
	p.play()

func trigger_meme() -> void:
	play_meme()
	if meme_list.size() > 0:
		var picked = meme_list[randi() % meme_list.size()]
		meme_triggered.emit(picked)

func trigger_effect(effect_name: StringName, extra_data: Variant = null) -> void:
	effect_requested.emit(effect_name, extra_data)

var bgm_player: AudioStreamPlayer
var bgm_stream: AudioStream
var is_music_started: bool = false

func start_bgm() -> void:
	# BGM removed per user request
	is_music_started = false

func stop_bgm() -> void:
	is_music_started = false
	if bgm_player:
		bgm_player.stop()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()

func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _setup_inputs() -> void:
	# Add Key A to ui_left if not present
	_add_key_to_action("ui_left", KEY_A)
	# Add Key D to ui_right if not present
	_add_key_to_action("ui_right", KEY_D)
	
	# Ensure start_action (Space)
	if not InputMap.has_action("start_action"):
		InputMap.add_action("start_action")
	_add_key_to_action("start_action", KEY_SPACE)
	
	# Ensure pause_action (Escape)
	if not InputMap.has_action("pause_action"):
		InputMap.add_action("pause_action")
	_add_key_to_action("pause_action", KEY_ESCAPE)

func _add_key_to_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
		if event is InputEventKey and event.keycode == keycode:
			return
	var new_event = InputEventKey.new()
	new_event.physical_keycode = keycode
	InputMap.action_add_event(action, new_event)

func load_best_score() -> void:
	if FileAccess.file_exists(BEST_SCORE_PATH):
		var file = FileAccess.open(BEST_SCORE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text().strip_edges()
			if content.is_valid_int():
				best_score = int(content)
			file.close()
	best_score_changed.emit(best_score)

func save_best_score() -> void:
	var file = FileAccess.open(BEST_SCORE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(best_score))
		file.close()

func start_game() -> void:
	score = 0
	combo = 0
	color_scheme_index = 0
	reached_500 = false
	reached_1000 = false
	reached_invert_controls = false
	are_controls_inverted = false
	controls_warning_active = false
	is_game_active = true
	score_changed.emit(score)
	combo_changed.emit(combo)
	color_scheme_changed.emit(color_scheme_index)
	# BGM removed per user request
	game_started.emit()

func update_score(new_score: int) -> void:
	if not is_game_active:
		return
	if new_score > score:
		score = new_score
		score_changed.emit(score)
		
		# Check milestones
		if score >= 500 and not reached_500:
			reached_500 = true
			milestone_reached.emit(500)
		if score >= 1000 and not reached_1000:
			reached_1000 = true
			milestone_reached.emit(1000)
			
		# Inverted controls check (temporarily 500 for testing, revert to 1000 later)
		if score >= INVERT_CONTROLS_THRESHOLD and not reached_invert_controls:
			reached_invert_controls = true
			_trigger_inverted_controls_sequence()
			
		# Check color scheme transitions (every 250 points)
		var new_scheme = mini(score / 250, COLOR_SCHEMES.size() - 1)
		if new_scheme != color_scheme_index:
			color_scheme_index = new_scheme
			color_scheme_changed.emit(color_scheme_index)

func _trigger_inverted_controls_sequence() -> void:
	controls_warning_active = true
	play_social_credit()
	controls_inverted_warning_started.emit()
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_game_active:
			are_controls_inverted = true
			controls_warning_active = false
			controls_inverted.emit()
	)

func increment_combo() -> void:
	combo += 1
	combo_changed.emit(combo)

func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)

func end_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	reset_combo()
	if score > best_score:
		best_score = score
		save_best_score()
		best_score_changed.emit(best_score)
	game_over.emit()
