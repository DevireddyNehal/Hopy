class_name EffectsManager
extends Node2D
## Central visual effects manager for HOPY.
##
## All effects are purely cosmetic and non-blocking (< 0.4s or gentle drift).
## They never alter player collision or control response.

const MAX_ACTIVE_PARTICLES: int = 120
const LANDING_COOLDOWN_MSEC: int = 40

const PIXEL_PATTERNS = [
	[".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."], # Heart
	["..X..", "..X..", "XXXXX", ".XXX.", "X...X"], # Star
	["...X.", "..XX.", ".XXXX", "..XX.", ".X..."], # Bolt
	["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."], # Sparkle
]
const PIXEL_COLORS = [
	Color(1.0, 0.45, 0.85), Color(0.45, 1.0, 1.0), Color(1.0, 0.95, 0.4), Color(0.7, 0.55, 1.0)
]
const CONFETTI_COLORS = [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.5),
	Color(0.3, 0.7, 1.0), Color(0.9, 0.4, 1.0), Color(1.0, 1.0, 1.0)
]
const SPARK_COLORS = [Color(0.3, 0.95, 1.0), Color(0.7, 0.55, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3)]
const SHATTER_COLORS = [Color(0.95, 0.55, 0.25), Color(0.55, 0.36, 1.0), Color(0.8, 0.8, 0.8)]

@onready var _container: Node2D = %Particles
@onready var _flash_rect: ColorRect = %FlashRect

var _pool: Array[Particle] = []
var _active: Array[Particle] = []
var _character: Node2D = null
var _base_modulate: Color = Color.WHITE
var _pulse_tween: Tween
var _flip_tween: Tween
var _flash_tween: Tween
var _last_landing_msec: Dictionary = {}

## One pooled visual particle. It has no physics body or collision.
class Particle extends Node2D:
	const SHAPE_CIRCLE: int = 0
	const SHAPE_SQUARE: int = 1
	const SHAPE_PIXEL: int = 2
	const SHAPE_CONFETTI: int = 3

	var velocity: Vector2 = Vector2.ZERO
	var gravity: float = 0.0
	var spin: float = 0.0
	var life: float = 1.0
	var age: float = 0.0
	var tint: Color = Color.WHITE
	var radius: float = 3.0
	var shape: int = SHAPE_CIRCLE
	var pattern: Array = []
	var manager: EffectsManager

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			if manager != null:
				manager.release_particle(self)
			return
		velocity.y += gravity * delta
		position += velocity * delta
		rotation += spin * delta
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(1.0 - age / life, 0.0, 1.0)
		var color := Color(tint.r, tint.g, tint.b, tint.a * k)
		match shape:
			SHAPE_CIRCLE:
				draw_circle(Vector2.ZERO, radius * 2.0, Color(color.r, color.g, color.b, color.a * 0.3))
				draw_circle(Vector2.ZERO, radius * (0.5 + k * 0.5), color)
			SHAPE_SQUARE:
				draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), color)
			SHAPE_CONFETTI:
				draw_rect(Rect2(-radius, -radius * 0.5, radius * 2.0, radius), color)
			SHAPE_PIXEL:
				for row in range(pattern.size()):
					var line: String = pattern[row]
					for col in range(line.length()):
						if line.substr(col, 1) == "X":
							draw_rect(Rect2((col - 2.5) * radius, (row - 2.5) * radius, radius, radius), color)

func _ready() -> void:
	if _container == null or not is_instance_valid(_container):
		push_error("EffectsManager: missing unique node 'Particles'.")
	# Connect to global GameState signals
	if GameState:
		if GameState.has_signal("effect_requested"):
			GameState.effect_requested.connect(trigger)
		if GameState.has_signal("milestone_reached"):
			GameState.milestone_reached.connect(_on_milestone)

func _on_milestone(points: int) -> void:
	var screen_center = get_viewport_rect().size / 2.0
	if points == 500:
		spawn_confetti(screen_center, 60, 2.0)
		flash_screen(Color(0.2, 1.0, 0.5, 0.35), 0.3)
	elif points == 1000:
		spawn_confetti(screen_center, 90, 2.5)
		flash_screen(Color(1.0, 0.85, 0.1, 0.5), 0.4)

## Bind character visual node (e.g. Sprite2D or Visuals container)
func bind_character(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	_character = visual
	_base_modulate = visual.modulate

## Public trigger API
func trigger(effect_type: StringName, extra_data: Variant = null) -> void:
	var world_pos: Vector2 = Vector2.ZERO
	if extra_data is Vector2:
		world_pos = extra_data

	match effect_type:
		&"sparkle":
			spawn_sparkle_burst(world_pos)
		&"pixel_emoji":
			spawn_pixel_emoji(world_pos)
		&"confetti":
			spawn_confetti(world_pos)
		&"shatter":
			spawn_shatter(world_pos)
		&"pulse":
			pulse_character()
		&"flip":
			flip_character()
		&"screen_flash":
			var flash_col = Color(1.0, 0.3, 0.3, 0.4)
			if extra_data is Color:
				flash_col = extra_data
			flash_screen(flash_col, 0.25)
		&"gold_flash":
			flash_screen(Color(1.0, 0.84, 0.0, 0.45), 0.35)

## Short burst of glowing sparks around the landing point (< 0.4s)
func spawn_sparkle_burst(world_pos: Vector2, count: int = 7) -> void:
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 200.0)
		var particle := _make_particle(world_pos, Vector2(cos(angle), sin(angle)) * speed,
			randf_range(0.2, 0.35), SPARK_COLORS[randi() % SPARK_COLORS.size()],
			randf_range(2.0, 3.0), Particle.SHAPE_CIRCLE)
		if particle == null:
			break
		particle.gravity = 140.0

## Pixel-style hearts, stars, bolts that rise then fade
func spawn_pixel_emoji(world_pos: Vector2, count: int = 4, life: float = 0.85) -> void:
	for i in range(count):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-90.0, 90.0), randf_range(-240.0, -150.0)),
			life * randf_range(0.7, 1.0),
			PIXEL_COLORS[randi() % PIXEL_COLORS.size()],
			2.5, Particle.SHAPE_PIXEL)
		if particle == null:
			break
		particle.pattern = PIXEL_PATTERNS[randi() % PIXEL_PATTERNS.size()]
		particle.gravity = 400.0
		particle.spin = randf_range(-2.0, 2.0)

## Confetti for celebrations and rainbow platform
func spawn_confetti(world_pos: Vector2, count: int = 22, life: float = 1.0) -> void:
	for i in range(count):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-200.0, 200.0), randf_range(-340.0, -140.0)),
			life * randf_range(0.7, 1.0),
			CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()],
			3.0, Particle.SHAPE_CONFETTI)
		if particle == null:
			break
		particle.gravity = 600.0
		particle.spin = randf_range(-8.0, 8.0)

## Shards that fly out when a crumble platform breaks
func spawn_shatter(world_pos: Vector2, count: int = 8) -> void:
	for i in range(count):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-160.0, 160.0), randf_range(-180.0, -40.0)),
			randf_range(0.25, 0.45),
			SHATTER_COLORS[randi() % SHATTER_COLORS.size()],
			3.0, Particle.SHAPE_SQUARE)
		if particle == null:
			break
		particle.gravity = 550.0
		particle.spin = randf_range(-6.0, 6.0)

## Flash character tint briefly on landing/bounce (< 0.18s)
func pulse_character(flash: Color = Color(1.5, 1.5, 1.5, 1.0), duration: float = 0.16) -> void:
	if _character == null or not is_instance_valid(_character):
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_character.modulate = _base_modulate
	else:
		_base_modulate = _character.modulate
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_character, "modulate", _base_modulate * flash, duration * 0.35)
	_pulse_tween.tween_property(_character, "modulate", _base_modulate, duration * 0.65)

## 360 spin mid-air on rainbow super-bounce (< 0.4s)
func flip_character(duration: float = 0.38) -> void:
	if _character == null or not is_instance_valid(_character):
		return
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_character.rotation = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(_character, "rotation", TAU, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_callback(func():
		if _character and is_instance_valid(_character):
			_character.rotation = 0.0
	)

## Fullscreen color flash (e.g. hazard or milestone)
func flash_screen(flash_color: Color = Color(1, 1, 1, 0.4), duration: float = 0.25) -> void:
	if not _flash_rect:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_rect.color = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _make_particle(world_pos: Vector2, velocity: Vector2, life: float, tint: Color,
		radius: float, shape: int) -> Particle:
	if _container == null or not is_instance_valid(_container):
		return null
	if _active.size() >= MAX_ACTIVE_PARTICLES:
		return null
	var particle: Particle
	if _pool.is_empty():
		particle = Particle.new()
		particle.manager = self
		_container.add_child(particle)
	else:
		particle = _pool.pop_back()
	particle.position = _container.to_local(world_pos)
	particle.rotation = 0.0
	particle.velocity = velocity
	particle.gravity = 0.0
	particle.spin = 0.0
	particle.life = life
	particle.age = 0.0
	particle.tint = tint
	particle.radius = radius
	particle.shape = shape
	particle.pattern = []
	particle.visible = true
	particle.set_process(true)
	particle.queue_redraw()
	_active.append(particle)
	return particle

func release_particle(particle: Particle) -> void:
	if not is_instance_valid(particle):
		_active.erase(particle)
		return
	var index: int = _active.find(particle)
	if index == -1:
		return
	_active.remove_at(index)
	particle.visible = false
	particle.set_process(false)
	_pool.append(particle)

func clear_all() -> void:
	for particle in _active.duplicate():
		release_particle(particle)
	_last_landing_msec.clear()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _character and is_instance_valid(_character):
		_character.modulate = _base_modulate
		_character.rotation = 0.0
