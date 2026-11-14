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
var is_game_active: bool = false

# ==============================================================================
# GAMEPLAY MODIFIER PIPELINE & PACING CONSTANTS
# ==============================================================================
# The game introduces its signature modifiers in a curated 2-phase sequence:
#
# Phase 1 — Curated Introduction (Strict Order):
#   1. DRUNK_BUFF_THRESHOLD (500 pts):
#      - 3-second non-intrusive warning countdown at top of HUD.
#      - When the effect starts, plays the drunk audio quote ("that guy is drunk").
#      - Activates full-screen liquid wavy nausea shader distortion & camera breathing roll.
#      - Grants +10% vertical bounce boost with gentle steering sway.
#      - Lasts for DRUNK_DURATION (8.0 seconds) then smoothly recovers.
#
#   2. INVERT_CONTROLS_THRESHOLD (700 pts = Drunk at 500 + 200 gap):
#      - 3-second social credit siren warning countdown.
#      - Reverses horizontal steering controls (Left <-> Right).
#      - Lasts for INVERT_DURATION (5.0 seconds) with live countdown badge, then restores.
#
# Phase 2 — Recurrent Endless Modifiers (Dynamic 500-Point Gap):
#   - After the first two ordered encounters (500 and 700), the game enters the endless loop.
#   - Every 500-point score gap (1200, 1700, 2200, 2700, 3200...), a modifier is picked
#     at random between Drunk Buff and Inverted Controls to keep high-score runs unpredictable.
const DRUNK_BUFF_THRESHOLD: int = 500          # 1st modifier: Drunk Buff at 500 score
const INVERT_CONTROLS_THRESHOLD: int = 700     # 2nd modifier: Inversion at 700 score (Drunk + 200)
const RECURRENT_MODIFIER_GAP: int = 500        # Gap between subsequent random modifiers (500 pts)
const FIRST_RECURRENT_SCORE: int = 1200        # First recurrent trigger: 700 + 500 = 1200

const INVERT_DURATION: float = 5.0             # Duration of reversed controls challenge (seconds)
const DRUNK_DURATION: float = 8.0              # Duration of drunk buff and screen nausea (seconds)

var reached_drunk: bool = false                # Flag: initial score 500 drunk sequence fired
var reached_invert_controls: bool = false      # Flag: initial score 700 invert sequence fired
var next_random_modifier_score: int = FIRST_RECURRENT_SCORE # Score threshold for next random modifier

var is_drunk: bool = false                     # True while drunk nausea & bounce boost are active
var drunk_warning_active: bool = false         # True during the 3-second pre-drunk warning
var are_controls_inverted: bool = false        # True while horizontal controls are reversed
var controls_warning_active: bool = false      # True during the 3-second pre-inversion warning

signal drunk_warning_started()                 # Fired when 3s drunk warning initiates
signal drunk_activated()                       # Fired when drunk effect begins (plays audio & nausea)
signal drunk_recovered()                       # Fired when drunk duration ends and recovers

signal controls_inverted_warning_started()     # Fired when 3s inversion warning initiates
signal controls_inverted()                     # Fired when controls invert for 5s
signal controls_restored()                     # Fired when controls return to normal

const BEST_SCORE_PATH: String = "user://best.txt"

# Color schemes: [Background color, Primary accent, Secondary accent] for biome transitions
const COLOR_SCHEMES = [
	{"bg": Color("08090c"), "accent1": Color("6366f1"), "accent2": Color("38bdf8")}, # 0-249: Obsidian Void
	{"bg": Color("0a0d14"), "accent1": Color("818cf8"), "accent2": Color("2dd4bf")}, # 250-499: Midnight Slate
	{"bg": Color("06120e"), "accent1": Color("10b981"), "accent2": Color("6ee7b7")}, # 500-749: Emerald Horizon
	{"bg": Color("0f0a1c"), "accent1": Color("a855f7"), "accent2": Color("f472b6")}, # 750-999: Twilight Violet
	{"bg": Color("040407"), "accent1": Color("c084fc"), "accent2": Color("38bdf8")}  # 1000+: Celestial Supernova
]

signal meme_triggered(meme_text: String)

var sfx_bounce: AudioStream
var sfx_rainbow: AudioStream
var sfx_meme: AudioStream
var sfx_start: AudioStream
var sfx_social_credit: AudioStream
var sfx_cat_laugh: AudioStream
var sfx_falling_scream: AudioStream
var sfx_drunk: AudioStream
var meme_list: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_load_audio_and_data()
	load_best_score()

var bounce_sounds: Array[AudioStream] = []

func _load_audio_and_data() -> void:
	bounce_sounds.clear()
	# Sound 0: Primary bounce sound (Mac Quack)
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
		
	# That guy is drunk sound
	if ResourceLoader.exists("res://assets/audio/drunk.mp3"):
		sfx_drunk = load("res://assets/audio/drunk.mp3")
		
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

func play_drunk() -> void:
	if not sfx_drunk:
		return
	var p = _get_sfx_player()
	p.stream = sfx_drunk
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
	# BGM disabled to prioritize arcade sound effects
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
	reached_drunk = false
	reached_invert_controls = false
	next_random_modifier_score = FIRST_RECURRENT_SCORE
	is_drunk = false
	drunk_warning_active = false
	are_controls_inverted = false
	controls_warning_active = false
	is_game_active = true
	score_changed.emit(score)
	combo_changed.emit(combo)
	color_scheme_changed.emit(color_scheme_index)
	# Soundscape remains focused on sound effects
	game_started.emit()

func update_score(new_score: int) -> void:
	if not is_game_active:
		return
	if new_score > score:
		score = new_score
		score_changed.emit(score)
		
		# --- Milestone Callouts & Fanfare ---
		if score >= 500 and not reached_500:
			reached_500 = true
			milestone_reached.emit(500)
		if score >= 1000 and not reached_1000:
			reached_1000 = true
			milestone_reached.emit(1000)
			
		# ======================================================================
		# GAMEPLAY MODIFIER PIPELINE (Ordered Intro -> Recurrent 500-pt Loop)
		# ======================================================================
		# Phase 1: Fixed Curated Introduction
		#   1st Modifier: Drunk Buff at 500 points (3s warning -> full-screen nausea + 10% jump)
		if score >= DRUNK_BUFF_THRESHOLD and not reached_drunk:
			reached_drunk = true
			_trigger_drunk_sequence()
			
		#   2nd Modifier: Inverted Controls at 700 points (Drunk at 500 + 200 gap)
		if score >= INVERT_CONTROLS_THRESHOLD and not reached_invert_controls:
			reached_invert_controls = true
			_trigger_inverted_controls_sequence()
			
		# Phase 2: Recurrent Endless Modifiers (Every 500-point gap after 700)
		#   Triggers at 1200, 1700, 2200, 2700, 3200...
		#   Randomly selects between Drunk Buff and Inverted Controls.
		if reached_invert_controls and score >= next_random_modifier_score:
			next_random_modifier_score += RECURRENT_MODIFIER_GAP
			_trigger_random_modifier()
			
		# --- Biome Background Palette Shifts (Every 250 points) ---
		var new_scheme = mini(score / 250, COLOR_SCHEMES.size() - 1)
		if new_scheme != color_scheme_index:
			color_scheme_index = new_scheme
			color_scheme_changed.emit(color_scheme_index)

## Triggers a random modifier for endless gameplay progression.
## Invoked every 500-point gap after the initial curated sequence (1200, 1700, 2200, etc.).
## Includes guards to prevent clashing overlays if an effect or warning is currently active.
func _trigger_random_modifier() -> void:
	if not is_game_active:
		return
	
	# Safety check: avoid overlapping modifiers if player is already dealing with one
	if is_drunk or are_controls_inverted or drunk_warning_active or controls_warning_active:
		return
		
	# 50/50 roll between Drunk Buff and Inverted Controls
	if randf() < 0.5:
		_trigger_drunk_sequence()
	else:
		_trigger_inverted_controls_sequence()

## Initiates the Inverted Controls challenge sequence:
## 1. 3-second non-intrusive warning with social credit sound and countdown badge.
## 2. Horizontal steer controls invert (Left <-> Right) for exactly INVERT_DURATION (5.0s).
## 3. Emits controls_restored() once the challenge completes to return steering to normal.
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
			
			# Challenge lasts for exactly INVERT_DURATION (5.0 seconds), then restores normal steering
			var restore_timer = get_tree().create_timer(INVERT_DURATION)
			restore_timer.timeout.connect(func():
				if is_game_active and are_controls_inverted:
					are_controls_inverted = false
					controls_restored.emit()
			)
	)

## Initiates the Drunk Buff challenge sequence:
## 1. 3-second non-intrusive warning with live indicator at the top of the HUD.
## 2. ONLY when the effect actually activates: plays the drunk audio ("that guy is drunk"),
##    turns on the full-screen liquid wavy nausea shader and wobbly camera breathing roll,
##    and applies the +10% vertical bounce boost.
## 3. Lasts for DRUNK_DURATION (8.0s), after which it recovers cleanly and emits drunk_recovered().
func _trigger_drunk_sequence() -> void:
	drunk_warning_active = true
	drunk_warning_started.emit()
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_game_active:
			is_drunk = true
			drunk_warning_active = false
			# Play audio quote on effect start
			play_drunk()
			drunk_activated.emit()
			
			# Buff & nausea last for DRUNK_DURATION (8.0 seconds), then recover
			var drunk_end_timer = get_tree().create_timer(DRUNK_DURATION)
			drunk_end_timer.timeout.connect(func():
				if is_game_active and is_drunk:
					is_drunk = false
					drunk_recovered.emit()
			)
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
