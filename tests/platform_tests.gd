extends Node
## Automated gameplay tests for platforms, PlayerAdapter, MemeText, and effects.
## Attach to a plain Node in an empty scene and run with F6.
## Landings are simulated by calling the platform's handlers directly.

const PLATFORM_SCENE: PackedScene = preload("res://scenes/Platform.tscn")
const EFFECTS_SCENE: PackedScene = preload("res://scenes/Effects.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const EPSILON: float = 0.001

var _passed: int = 0
var _failed: int = 0


class MockPlayer extends CharacterBody2D:
	var bounce_calls: int = 0
	var boosted_calls: int = 0
	var last_boost: float = 0.0
	var landing_notifications: int = 0
	var steering := PlayerAdapter.SteeringModifier.new()

	func _init() -> void:
		add_to_group(PlayerAdapter.PLAYER_GROUP)

	func on_platform_landed(_platform_type: int, _landing_position: Vector2) -> void:
		landing_notifications += 1

	func apply_default_bounce() -> void:
		bounce_calls += 1
		velocity.y = -700.0

	func apply_boosted_bounce(velocity_y: float) -> void:
		boosted_calls += 1
		last_boost = velocity_y
		velocity.y = velocity_y

	func apply_steering_modifier(multiplier: float, duration: float) -> void:
		steering.request(multiplier, duration)


func _ready() -> void:
	await run_all()
	print("=== RESULTS: %d passed, %d failed ===" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failed > 0 else 0)


func run_all() -> void:
	await test_normal_bounce()
	await test_rising_player_does_not_bounce()
	await test_duplicate_contact_is_ignored()
	await test_rainbow_boost_is_1_5x()
	await test_glitch_slowdown_and_expiry()
	await test_glitch_restart_does_not_stack()
	await test_crumble_breaks_once()
	await test_destroyed_platform_is_safe()
	await test_moving_platform_stays_in_bounds()
	await test_non_player_body_is_ignored()
	await test_special_sequence()
	await test_crumble_second_landing_does_not_bounce()
	test_meme_loader_returns_messages()
	await test_glitch_overlay_exists_and_toggles()
	await test_rainbow_trail_starts_and_expires()
	await test_trigger_accepts_missing_position()
	await test_main_scene_game_flow()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


func _make_platform(kind: Platform.Kind) -> Platform:
	var platform: Platform = PLATFORM_SCENE.instantiate() as Platform
	platform.kind = kind
	add_child(platform)
	return platform


func _make_player() -> MockPlayer:
	var player := MockPlayer.new()
	add_child(player)
	return player


func _land(platform: Platform, player: MockPlayer) -> void:
	player.velocity.y = 400.0
	platform._on_landing_sensor_body_entered(player)


func _leave(platform: Platform, player: MockPlayer) -> void:
	platform._on_landing_sensor_body_exited(player)


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().process_frame


func test_normal_bounce() -> void:
	print("Normal platform")
	var platform := _make_platform(Platform.Kind.NORMAL)
	var player := _make_player()
	_land(platform, player)
	_check(player.bounce_calls == 1, "landing calls default bounce once")
	_check(absf(player.velocity.y - (-700.0)) < EPSILON, "normal bounce sets velocity to -700")
	_check(player.landing_notifications == 1, "landing notification sent to player")
	_check(platform.is_active(), "normal platform stays after landing")
	await _cleanup([platform, player])


func test_rising_player_does_not_bounce() -> void:
	print("Rising player")
	var platform := _make_platform(Platform.Kind.NORMAL)
	var player := _make_player()
	player.velocity.y = -300.0
	platform._on_landing_sensor_body_entered(player)
	_check(player.bounce_calls == 0, "rising player does not trigger a bounce")
	await _cleanup([platform, player])


func test_duplicate_contact_is_ignored() -> void:
	print("Duplicate contact")
	var platform := _make_platform(Platform.Kind.NORMAL)
	var player := _make_player()
	_land(platform, player)
	_land(platform, player)
	_check(player.bounce_calls == 1, "second contact without exit is ignored")
	_leave(platform, player)
	_land(platform, player)
	_check(player.bounce_calls == 2, "landing after exit is accepted")
	await _cleanup([platform, player])


func test_rainbow_boost_is_1_5x() -> void:
	print("Rainbow platform")
	var platform := _make_platform(Platform.Kind.RAINBOW)
	var player := _make_player()
	_land(platform, player)
	_check(player.boosted_calls == 1, "rainbow uses boosted bounce")
	_check(player.bounce_calls == 0, "rainbow does not use default bounce")
	_check(absf(player.last_boost - (-1050.0)) < EPSILON, "rainbow velocity is -1050")
	_check(absf(player.last_boost / -700.0 - 1.5) < EPSILON, "rainbow is 1.5x normal bounce")
	await _cleanup([platform, player])


func test_glitch_slowdown_and_expiry() -> void:
	print("Glitch platform")
	var platform := _make_platform(Platform.Kind.GLITCH)
	var player := _make_player()
	_land(platform, player)
	_check(absf(player.steering.multiplier - 0.5) < EPSILON, "glitch halves steering")
	_check(player.steering.is_active(), "slowdown is active after landing")
	player.steering.update(0.5)
	_check(absf(player.steering.multiplier - 0.5) < EPSILON, "slowdown still active at 0.5 s")
	player.steering.update(0.6)
	_check(absf(player.steering.multiplier - 1.0) < EPSILON, "steering restored after 1 s")
	_check(not player.steering.is_active(), "slowdown is no longer active")
	await _cleanup([platform, player])


func test_glitch_restart_does_not_stack() -> void:
	print("Glitch slowdown reset")
	var platform := _make_platform(Platform.Kind.GLITCH)
	var player := _make_player()
	_land(platform, player)
	player.steering.update(0.8)
	_leave(platform, player)
	_land(platform, player)
	player.steering.update(0.5)
	_check(absf(player.steering.multiplier - 0.5) < EPSILON, "second glitch restarts the 1 s timer")
	player.steering.update(0.6)
	_check(absf(player.steering.multiplier - 1.0) < EPSILON, "restored 1 s after the second landing")
	await _cleanup([platform, player])


func test_crumble_breaks_once() -> void:
	print("Crumble platform")
	var platform := _make_platform(Platform.Kind.CRUMBLE)
	var player := _make_player()
	var destroyed := [0]
	var starts := [0]
	platform.platform_destroyed.connect(func(_platform: Platform) -> void: destroyed[0] += 1)
	platform.special_effect_triggered.connect(func(effect_type: StringName, _pos: Vector2) -> void:
		if effect_type == &"crumble_start":
			starts[0] += 1)
	_land(platform, player)
	_leave(platform, player)
	await get_tree().create_timer(0.1).timeout
	_land(platform, player)
	_check(starts[0] == 1, "crumble timer starts only once")
	await get_tree().create_timer(0.8).timeout
	_check(destroyed[0] == 1, "crumble platform is destroyed exactly once")
	_check(not is_instance_valid(platform) or platform.is_queued_for_deletion(), "crumble platform is removed")
	await _cleanup([player])


func test_destroyed_platform_is_safe() -> void:
	print("Destroyed platform")
	var platform := _make_platform(Platform.Kind.NORMAL)
	var player := _make_player()
	var destroyed := [0]
	platform.platform_destroyed.connect(func(_platform: Platform) -> void: destroyed[0] += 1)
	platform.despawn()
	platform.despawn()
	_check(destroyed[0] == 1, "repeated despawn emits platform_destroyed once")
	_land(platform, player)
	_check(player.bounce_calls == 0, "destroyed platform ignores landings")
	await _cleanup([platform, player])


func test_moving_platform_stays_in_bounds() -> void:
	print("Moving platform")
	var platform := _make_platform(Platform.Kind.MOVING)
	platform.move_left_distance = 50.0
	platform.move_right_distance = 50.0
	platform.move_speed = 120.0
	platform.set_physics_process(false)
	var min_x: float = INF
	var max_x: float = -INF
	for i in range(2000):
		platform._physics_process(1.0 / 60.0)
		min_x = minf(min_x, platform.position.x)
		max_x = maxf(max_x, platform.position.x)
	_check(min_x >= -50.0 - EPSILON, "moving platform stays within left limit")
	_check(max_x <= 50.0 + EPSILON, "moving platform stays within right limit")
	_check(max_x - min_x > 90.0, "moving platform actually travels between limits")
	await _cleanup([platform])


func test_non_player_body_is_ignored() -> void:
	print("Non-player body")
	var platform := _make_platform(Platform.Kind.NORMAL)
	var other := CharacterBody2D.new()
	add_child(other)
	var landed := [0]
	platform.platform_landed.connect(func(_kind: Platform.Kind, _pos: Vector2) -> void: landed[0] += 1)
	other.velocity.y = 400.0
	platform._on_landing_sensor_body_entered(other)
	_check(landed[0] == 0, "body outside the player group does not trigger a landing")
	await _cleanup([platform, other])


func test_special_sequence() -> void:
	print("Special platforms in sequence")
	var kinds := [
		Platform.Kind.NORMAL, Platform.Kind.RAINBOW,
		Platform.Kind.GLITCH, Platform.Kind.MEME
	]
	var player := _make_player()
	var platforms: Array = []
	for kind in kinds:
		var platform := _make_platform(kind)
		platforms.append(platform)
		_land(platform, player)
	_check(player.landing_notifications == 4, "each platform triggers exactly one landing")
	_check(player.bounce_calls == 3, "three default bounces (normal, glitch, meme)")
	_check(player.boosted_calls == 1, "one boosted bounce (rainbow)")
	platforms.append(player)
	await _cleanup(platforms)


func test_crumble_second_landing_does_not_bounce() -> void:
	print("Crumble rebounce guard")
	var platform := _make_platform(Platform.Kind.CRUMBLE)
	var player := _make_player()
	_land(platform, player)
	_check(player.bounce_calls == 1, "first crumble landing bounces once")
	_leave(platform, player)
	_land(platform, player)
	_check(player.bounce_calls == 1, "second landing after crumble starts does not bounce")
	await _cleanup([platform, player])


func test_meme_loader_returns_messages() -> void:
	print("Meme text loader")
	var messages: PackedStringArray = MemeText.load_messages()
	_check(not messages.is_empty(), "meme loader returns at least one message")
	var all_text: bool = true
	for message in messages:
		if message.strip_edges().is_empty():
			all_text = false
	_check(all_text, "meme loader returns no empty messages")


func test_glitch_overlay_exists_and_toggles() -> void:
	print("Glitch overlay")
	var effects: EffectsManager = EFFECTS_SCENE.instantiate() as EffectsManager
	add_child(effects)
	await get_tree().process_frame
	_check(effects._glitch_rect != null, "glitch overlay rect was built")
	_check(effects._glitch_rect != null and not effects._glitch_rect.visible, "glitch overlay starts hidden")
	effects.play_glitch(0.2)
	_check(effects._glitch_rect != null and effects._glitch_rect.visible, "play_glitch shows the overlay")
	await get_tree().create_timer(0.4).timeout
	_check(effects._glitch_rect == null or not effects._glitch_rect.visible, "overlay hides after its duration")
	await _cleanup([effects])


func test_rainbow_trail_starts_and_expires() -> void:
	print("Rainbow trail")
	var effects: EffectsManager = EFFECTS_SCENE.instantiate() as EffectsManager
	add_child(effects)
	await get_tree().process_frame
	effects.start_rainbow_trail(0.2)
	_check(effects._trail_left > 0.0, "trail is active after start_rainbow_trail")
	await get_tree().create_timer(0.4).timeout
	_check(effects._trail_left <= 0.0, "trail expires after its duration")
	await _cleanup([effects])


func test_trigger_accepts_missing_position() -> void:
	print("Trigger API without position")
	var effects: EffectsManager = EFFECTS_SCENE.instantiate() as EffectsManager
	add_child(effects)
	await get_tree().process_frame
	effects.trigger(&"pulse")
	effects.trigger(&"flip")
	effects.trigger(&"glitch")
	_check(true, "pulse, flip, and glitch accept an omitted position")
	await _cleanup([effects])


func test_main_scene_game_flow() -> void:
	print("Main scene game flow")
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	_check(main.get_node_or_null("UILayer/TitleScreen") != null, "main scene opens on the title screen")

	main.call("_start_game")
	await get_tree().process_frame
	var run: Node = main.get_node_or_null("World/Run")
	_check(GameState.is_game_active, "starting the run activates GameState")
	_check(run != null and run.get_node_or_null("Player") != null, "starting the run adds the player")
	_check(run != null and run.get_child_count() >= 4, "starting the run creates platforms and effects")

	main.call("_open_pause_screen")
	_check(get_tree().paused, "pause action pauses the scene tree")
	main.call("_resume_game")
	_check(not get_tree().paused, "resume action unpauses the scene tree")

	main.call("_return_to_title")
	await get_tree().process_frame
	_check(not GameState.is_game_active, "returning to title ends the run")
	_check(main.get_node_or_null("UILayer/TitleScreen") != null, "returning to title shows the title screen")
	await _cleanup([main])
