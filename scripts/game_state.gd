extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal best_score_changed(new_best: int)
signal color_scheme_changed(scheme_index: int)
signal milestone_reached(points: int)
signal game_started
signal game_over
signal game_paused(is_paused: bool)

var score: int = 0
var combo: int = 0
var best_score: int = 0
var color_scheme_index: int = 0

var reached_500: bool = false
var reached_1000: bool = false
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

var sfx_bounce: AudioStream
var sfx_rainbow: AudioStream
var sfx_meme: AudioStream
var meme_list: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_load_audio_and_data()
	load_best_score()

func _load_audio_and_data() -> void:
	# "Hee-Hee!" is the default bounce sound!
	if ResourceLoader.exists("res://assets/audio/rainbow.mp3"):
		sfx_bounce = load("res://assets/audio/rainbow.mp3")
	elif ResourceLoader.exists("res://assets/audio/bounce.wav"):
		sfx_bounce = load("res://assets/audio/bounce.wav")
		
	# Rainbow super-bounce
	if ResourceLoader.exists("res://assets/audio/rainbow.mp3"):
		sfx_rainbow = load("res://assets/audio/rainbow.mp3")
	elif ResourceLoader.exists("res://assets/audio/bounce.wav"):
		sfx_rainbow = load("res://assets/audio/bounce.wav")
		
	if ResourceLoader.exists("res://assets/audio/meme.mp3"):
		sfx_meme = load("res://assets/audio/meme.mp3")
		
	# Load memes
	if FileAccess.file_exists("res://data/meme_text.json"):
		var f = FileAccess.open("res://data/meme_text.json", FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Array:
				meme_list = json.data
			f.close()

func play_bounce() -> void:
	if not sfx_bounce:
		return
	var p = AudioStreamPlayer.new()
	p.stream = sfx_bounce
	p.pitch_scale = clampf(1.0 + (combo * 0.05), 0.9, 2.3)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_rainbow() -> void:
	if not sfx_rainbow:
		return
	var p = AudioStreamPlayer.new()
	p.stream = sfx_rainbow
	p.pitch_scale = 1.35 # Extra high-pitched super Hee-Hee!
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_meme() -> void:
	if not sfx_meme:
		return
	var p = AudioStreamPlayer.new()
	p.stream = sfx_meme
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func trigger_meme() -> void:
	play_meme()
	if meme_list.size() > 0:
		var picked = meme_list[randi() % meme_list.size()]
		meme_triggered.emit(picked)

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
	is_game_active = true
	score_changed.emit(score)
	combo_changed.emit(combo)
	color_scheme_changed.emit(color_scheme_index)
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
			
		# Check color scheme transitions (every 250 points)
		var new_scheme = mini(score / 250, COLOR_SCHEMES.size() - 1)
		if new_scheme != color_scheme_index:
			color_scheme_index = new_scheme
			color_scheme_changed.emit(color_scheme_index)

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
