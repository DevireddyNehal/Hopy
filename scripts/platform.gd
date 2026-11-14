class_name Platform
extends AnimatableBody2D
## Reusable special platform for HOPY.
##
## The player is detected by the LandingSensor Area2D above the platform top.
## This script never reads or writes the player's movement or physics. It only
## calls PlayerAdapter, which calls methods the main programmer implements.

enum Kind { NORMAL, MOVING, CRUMBLE, RAINBOW, GLITCH, MEME }

## Emitted once per landing contact.
signal platform_landed(platform_type: Kind, landing_position: Vector2)
## Emitted once when this platform is removed (crumble break or despawn()).
signal platform_destroyed(platform: Platform)
## Emitted for every visual/audio effect request. Effects manager listens here.
signal special_effect_triggered(effect_type: StringName, effect_position: Vector2)
## Informational only. The player receives the slowdown via PlayerAdapter.
signal steering_modifier_requested(multiplier: float, duration: float)

const MOVING_SPEED_DEFAULT: float = 120.0
const MOVING_ACCEL: float = 600.0
const CRUMBLE_DELAY: float = 0.15
const CRUMBLE_BREAK_TIME: float = 0.35
const RAINBOW_BOUNCE_VELOCITY: float = -1050.0
const GLITCH_STEER_MULTIPLIER: float = 0.5
const GLITCH_DURATION: float = 1.0
const MEME_DURATION: float = 2.0
const MEME_RISE: float = 60.0

@export var kind: Kind = Kind.NORMAL:
	set(value):
		kind = value
		if is_node_ready():
			_visual.color = _kind_color()
@export var move_speed: float = MOVING_SPEED_DEFAULT
## Distance (px) the moving platform travels left of its spawn x.
@export var move_left_distance: float = 120.0
## Distance (px) the moving platform travels right of its spawn x.
@export var move_right_distance: float = 120.0
## +1.0 starts moving right, -1.0 starts moving left.
@export var start_direction: float = 1.0
## Leave empty to load messages from data/meme_text.json.
@export var meme_messages: PackedStringArray = PackedStringArray()

var _origin_x: float = 0.0
var _direction: float = 1.0
var _velocity_x: float = 0.0
var _contacts: Dictionary = {}
var _crumble_started: bool = false
var _destroyed: bool = false
var _glitch_tween: Tween
var _rainbow_tween: Tween

@onready var _visual: Polygon2D = %Visual
@onready var _body_shape: CollisionShape2D = %BodyShape
@onready var _sensor: Area2D = %LandingSensor
@onready var _crumble_timer: Timer = %CrumbleTimer


func _ready() -> void:
	sync_to_physics = true
	_origin_x = position.x
	_direction = -1.0 if start_direction < 0.0 else 1.0
	_crumble_timer.wait_time = CRUMBLE_DELAY
	_visual.color = _kind_color()
	if meme_messages.is_empty():
		meme_messages = MemeText.load_messages()
	_sensor.body_entered.connect(_on_landing_sensor_body_entered)
	_sensor.body_exited.connect(_on_landing_sensor_body_exited)
	_crumble_timer.timeout.connect(_on_crumble_timer_timeout)


func _physics_process(delta: float) -> void:
	if _destroyed or kind != Kind.MOVING:
		return
	_update_horizontal_motion(delta)


func is_active() -> bool:
	return not _destroyed and not is_queued_for_deletion()


## Safely removes the platform. platform_destroyed is emitted exactly once.
func despawn() -> void:
	if is_queued_for_deletion():
		return
	_destroyed = true
	_contacts.clear()
	_body_shape.set_deferred("disabled", true)
	_sensor.set_deferred("monitoring", false)
	platform_destroyed.emit(self)
	queue_free()


func _update_horizontal_motion(delta: float) -> void:
	var left_limit: float = _origin_x - move_left_distance
	var right_limit: float = _origin_x + move_right_distance
	if position.x >= right_limit:
		_direction = -1.0
	elif position.x <= left_limit:
		_direction = 1.0
	var target_velocity: float = _direction * move_speed
	_velocity_x = move_toward(_velocity_x, target_velocity, MOVING_ACCEL * delta)
	position.x = clampf(position.x + _velocity_x * delta, left_limit, right_limit)


func _on_landing_sensor_body_entered(body: Node2D) -> void:
	if _destroyed or not is_instance_valid(body):
		return
	if not PlayerAdapter.is_player(body):
		return
	var player := body as CharacterBody2D
	if player.velocity.y <= 0.0:
		return
	if kind == Kind.CRUMBLE and _crumble_started:
		return
	var id: int = player.get_instance_id()
	if _contacts.has(id):
		return
	_contacts[id] = true
	_handle_landing(player)


func _on_landing_sensor_body_exited(body: Node2D) -> void:
	if is_instance_valid(body):
		_contacts.erase(body.get_instance_id())


func _handle_landing(player: CharacterBody2D) -> void:
	var landing_position: Vector2 = player.global_position
	platform_landed.emit(kind, landing_position)
	PlayerAdapter.notify_landing(player, kind, landing_position)

	match kind:
		Kind.NORMAL, Kind.MOVING:
			PlayerAdapter.apply_default_bounce(player)

		Kind.CRUMBLE:
			PlayerAdapter.apply_default_bounce(player)
			_start_crumble(landing_position)

		Kind.RAINBOW:
			PlayerAdapter.apply_boosted_bounce(player, RAINBOW_BOUNCE_VELOCITY)
			_play_rainbow()
			special_effect_triggered.emit(&"rainbow", landing_position)

		Kind.GLITCH:
			PlayerAdapter.apply_default_bounce(player)
			PlayerAdapter.apply_steering_modifier(player, GLITCH_STEER_MULTIPLIER, GLITCH_DURATION)
			steering_modifier_requested.emit(GLITCH_STEER_MULTIPLIER, GLITCH_DURATION)
			_play_glitch()
			special_effect_triggered.emit(&"glitch", landing_position)

		Kind.MEME:
			PlayerAdapter.apply_default_bounce(player)
			_spawn_meme_popup(landing_position)
			special_effect_triggered.emit(&"meme", landing_position)


## Crumble timer starts once. Later landings are ignored.
func _start_crumble(landing_position: Vector2) -> void:
	if _crumble_started or _destroyed:
		return
	_crumble_started = true
	_crumble_timer.start(CRUMBLE_DELAY)
	special_effect_triggered.emit(&"crumble_start", landing_position)


func _on_crumble_timer_timeout() -> void:
	_break_apart()


func _break_apart() -> void:
	if _destroyed:
		return
	_destroyed = true
	_contacts.clear()
	_body_shape.set_deferred("disabled", true)
	_sensor.set_deferred("monitoring", false)
	special_effect_triggered.emit(&"crumble_break", global_position)

	var tween: Tween = create_tween()
	tween.tween_property(_visual, "modulate:a", 0.0, CRUMBLE_BREAK_TIME)
	tween.parallel().tween_property(_visual, "position:y", _visual.position.y + 24.0, CRUMBLE_BREAK_TIME)
	tween.tween_callback(despawn)


func _play_glitch() -> void:
	if _glitch_tween and _glitch_tween.is_valid():
		_glitch_tween.kill()
	var glitch_colors: Array[Color] = [
		Color(1.0, 0.2, 0.8), Color(0.2, 1.0, 1.0), Color(1.0, 1.0, 0.3), Color(0.4, 1.0, 0.4)
	]
	_glitch_tween = create_tween()
	for i in range(glitch_colors.size() * 2):
		_glitch_tween.tween_property(_visual, "modulate", glitch_colors[i % glitch_colors.size()], 0.05)
		_glitch_tween.tween_property(_visual, "modulate", Color.WHITE, 0.1)


func _play_rainbow() -> void:
	if _rainbow_tween and _rainbow_tween.is_valid():
		_rainbow_tween.kill()
	var rainbow_colors: Array[Color] = [
		Color(1.0, 0.4, 0.4), Color(1.0, 0.9, 0.4), Color(0.5, 1.0, 0.5),
		Color(0.4, 0.8, 1.0), Color(0.8, 0.5, 1.0)
	]
	_rainbow_tween = create_tween()
	for color in rainbow_colors:
		_rainbow_tween.tween_property(_visual, "modulate", color, 0.08)
	_rainbow_tween.tween_property(_visual, "modulate", Color.WHITE, 0.15)


## Floating text is added to the current scene so it survives platform removal.
func _spawn_meme_popup(at: Vector2) -> void:
	if meme_messages.is_empty():
		return
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var popup := Node2D.new()
	popup.name = "MemePopup"
	var label := Label.new()
	label.text = meme_messages[randi() % meme_messages.size()]
	label.position = Vector2(-90.0, -14.0)
	label.custom_minimum_size = Vector2(180.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	popup.add_child(label)
	host.add_child.call_deferred(popup)
	_start_meme_tween.call_deferred(popup, at)


func _start_meme_tween(popup: Node2D, at: Vector2) -> void:
	if not is_instance_valid(popup):
		return
	popup.global_position = at + Vector2(0.0, -50.0)
	var tween: Tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - MEME_RISE, MEME_DURATION)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, MEME_DURATION)
	tween.tween_callback(popup.queue_free)


func _kind_color() -> Color:
	match kind:
		Kind.NORMAL:
			return Color(0.55, 0.36, 1.0)
		Kind.MOVING:
			return Color(0.1, 0.85, 1.0)
		Kind.CRUMBLE:
			return Color(0.95, 0.55, 0.25)
		Kind.RAINBOW:
			return Color(1.0, 0.85, 0.4)
		Kind.GLITCH:
			return Color(0.3, 1.0, 0.45)
		Kind.MEME:
			return Color(1.0, 0.85, 0.2)
	return Color.WHITE