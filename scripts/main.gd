extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://scenes/Platform.tscn")
const EFFECTS_SCENE: PackedScene = preload("res://scenes/Effects.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://scenes/TitleScreen.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/HUD.tscn")
const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/DeathScreen.tscn")
const PAUSE_SCREEN_SCENE: PackedScene = preload("res://scenes/PauseScreen.tscn")
const BASE_PLATFORM_POSITION := Vector2(576.0, 510.0)
const PLAYER_START_POSITION := Vector2(576.0, 420.0)
const SCORE_PIXELS_PER_POINT: float = 5.0

@onready var _world: Node2D = $World
@onready var _camera: Camera2D = $Camera2D
@onready var _background: ColorRect = $BackgroundLayer/Background
@onready var _ui_layer: CanvasLayer = $UILayer

var _rng := RandomNumberGenerator.new()
var _run_root: Node2D
var _player: CharacterBody2D
var _effects: EffectsManager
var _platforms: Array[Platform] = []
var _highest_platform_y: float = 0.0
var _highest_player_y: float = PLAYER_START_POSITION.y
var _title_screen: Control
var _hud: Control
var _pause_screen: Control
var _death_screen: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_camera.position = Vector2(576.0, 324.0)
	_background.color = GameState.COLOR_SCHEMES[0]["bg"]
	GameState.color_scheme_changed.connect(_on_color_scheme_changed)
	_show_title_screen()


func _process(_delta: float) -> void:
	if not GameState.is_game_active or get_tree().paused or not is_instance_valid(_player):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if _player.global_position.y < _camera.global_position.y + 96.0:
		_camera.global_position.y = _player.global_position.y - 96.0

	_highest_player_y = minf(_highest_player_y, _player.global_position.y)
	GameState.update_score(int((_highest_player_y - PLAYER_START_POSITION.y) / SCORE_PIXELS_PER_POINT))
	_spawn_platforms_ahead(viewport_size.y)
	_remove_distant_platforms(viewport_size.y)

	if _player.global_position.y > _camera.global_position.y + viewport_size.y * 0.5 + 80.0:
		_end_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_action"):
		if GameState.is_game_active:
			_open_pause_screen()
		elif get_tree().paused and is_instance_valid(_pause_screen):
			_resume_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"start_action") and not GameState.is_game_active:
		if is_instance_valid(_title_screen) or is_instance_valid(_death_screen):
			_start_game()
			get_viewport().set_input_as_handled()


func _show_title_screen() -> void:
	_title_screen = TITLE_SCREEN_SCENE.instantiate() as Control
	_ui_layer.add_child(_title_screen)
	_title_screen.call("set_best_score", GameState.best_score)
	_title_screen.connect(&"start_requested", Callable(self, "_start_game"))


func _start_game() -> void:
	get_tree().paused = false
	GameState.game_paused.emit(false)
	_clear_ui()
	_clear_run()
	GameState.start_game()

	_run_root = Node2D.new()
	_run_root.name = "Run"
	_world.add_child(_run_root)

	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	if _player == null:
		push_error("Main: could not instantiate scenes/Player.tscn.")
		return
	_player.position = PLAYER_START_POSITION
	_run_root.add_child(_player)

	_effects = EFFECTS_SCENE.instantiate() as EffectsManager
	if _effects == null:
		push_error("Main: could not instantiate scenes/Effects.tscn.")
		return
	_run_root.add_child(_effects)
	var visual := _player.get_node_or_null("Visual") as Node2D
	if visual == null:
		push_error("Main: Player.tscn is missing its Visual node.")
		return
	_effects.bind_character(visual)

	_platforms.clear()
	_highest_platform_y = BASE_PLATFORM_POSITION.y
	_highest_player_y = PLAYER_START_POSITION.y
	_camera.position = Vector2(576.0, 324.0)
	_add_platform(Platform.Kind.NORMAL, BASE_PLATFORM_POSITION)
	_spawn_platforms_ahead(get_viewport().get_visible_rect().size.y)
	_show_hud()


func _add_platform(kind: Platform.Kind, spawn_position: Vector2) -> void:
	var platform := PLATFORM_SCENE.instantiate() as Platform
	if platform == null:
		push_error("Main: could not instantiate scenes/Platform.tscn.")
		return
	platform.kind = kind
	platform.position = spawn_position
	if kind == Platform.Kind.MOVING:
		platform.move_left_distance = 90.0
		platform.move_right_distance = 90.0
	_run_root.add_child(platform)
	platform.platform_destroyed.connect(_on_platform_destroyed)
	_effects.connect_platform(platform)
	_platforms.append(platform)


func _spawn_platforms_ahead(viewport_height: float) -> void:
	var spawn_limit: float = _camera.global_position.y - viewport_height * 1.25
	while _highest_platform_y > spawn_limit:
		_highest_platform_y -= _rng.randf_range(78.0, 128.0)
		var viewport_width: float = get_viewport().get_visible_rect().size.x
		var x: float = _rng.randf_range(80.0, viewport_width - 80.0)
		_add_platform(_choose_platform_kind(), Vector2(x, _highest_platform_y))


func _choose_platform_kind() -> Platform.Kind:
	var roll: float = _rng.randf()
	if roll < 0.08:
		return Platform.Kind.MOVING
	if roll < 0.16:
		return Platform.Kind.CRUMBLE
	if roll < 0.20:
		return Platform.Kind.RAINBOW
	if roll < 0.25:
		return Platform.Kind.GLITCH
	if roll < 0.30:
		return Platform.Kind.MEME
	return Platform.Kind.NORMAL


func _remove_distant_platforms(viewport_height: float) -> void:
	var remove_below: float = _camera.global_position.y + viewport_height * 0.75
	for platform in _platforms.duplicate():
		if is_instance_valid(platform) and platform.global_position.y > remove_below:
			platform.despawn()


func _on_platform_destroyed(platform: Platform) -> void:
	_platforms.erase(platform)


func _show_hud() -> void:
	_hud = HUD_SCENE.instantiate() as Control
	_ui_layer.add_child(_hud)
	_hud.call("set_best_score", GameState.best_score)
	_hud.connect(&"pause_requested", Callable(self, "_open_pause_screen"))


func _open_pause_screen() -> void:
	if not GameState.is_game_active or is_instance_valid(_pause_screen):
		return
	get_tree().paused = true
	GameState.game_paused.emit(true)
	_pause_screen = PAUSE_SCREEN_SCENE.instantiate() as Control
	_ui_layer.add_child(_pause_screen)
	_pause_screen.connect(&"resume_requested", Callable(self, "_resume_game"))
	_pause_screen.connect(&"restart_requested", Callable(self, "_start_game"))
	_pause_screen.connect(&"title_requested", Callable(self, "_return_to_title"))


func _resume_game() -> void:
	if is_instance_valid(_pause_screen):
		_pause_screen.queue_free()
	_pause_screen = null
	get_tree().paused = false
	GameState.game_paused.emit(false)


func _end_run() -> void:
	if not GameState.is_game_active:
		return
	GameState.end_game()
	get_tree().paused = true
	GameState.game_paused.emit(true)
	_death_screen = DEATH_SCREEN_SCENE.instantiate() as Control
	_ui_layer.add_child(_death_screen)
	_death_screen.call("set_results", GameState.score, GameState.best_score)
	_death_screen.connect(&"restart_requested", Callable(self, "_start_game"))
	_death_screen.connect(&"title_requested", Callable(self, "_return_to_title"))


func _return_to_title() -> void:
	if GameState.is_game_active:
		GameState.end_game()
	get_tree().paused = false
	GameState.game_paused.emit(false)
	_clear_ui()
	_clear_run()
	_show_title_screen()


func _clear_ui() -> void:
	for screen in [_title_screen, _hud, _pause_screen, _death_screen]:
		if is_instance_valid(screen):
			screen.queue_free()
	_title_screen = null
	_hud = null
	_pause_screen = null
	_death_screen = null


func _clear_run() -> void:
	if is_instance_valid(_run_root):
		_run_root.queue_free()
	_run_root = null
	_player = null
	_effects = null
	_platforms.clear()


func _on_color_scheme_changed(scheme_index: int) -> void:
	var index: int = clampi(scheme_index, 0, GameState.COLOR_SCHEMES.size() - 1)
	_background.color = GameState.COLOR_SCHEMES[index]["bg"]
