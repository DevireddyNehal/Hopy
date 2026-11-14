class_name EffectsManager
extends Node2D
## Central visual effects manager for HOPY.
##
## Instance scenes/Effects.tscn once in the game world, alongside platforms.
## Effects are cosmetic and never change player physics or collision.

const MAX_ACTIVE_PARTICLES: int = 400
const LANDING_COOLDOWN_MSEC: int = 50
const RAINBOW_TRAIL_DURATION: float = 0.6
const RAINBOW_TRAIL_INTERVAL: float = 0.035
const GLITCH_OVERLAY_DURATION: float = 1.0
const GLITCH_SHADER_PATH: String = "res://shaders/glitch.gdshader"

const PIXEL_PATTERNS = [
	[".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."],
	["..X..", "..X..", "XXXXX", ".XXX.", "X...X"],
	["...X.", "..XX.", ".XXXX", "..XX.", ".X..."],
	["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."],
]
const PIXEL_COLORS = [
	Color(1.0, 0.45, 0.85), Color(0.45, 1.0, 1.0), Color(1.0, 0.95, 0.4), Color(0.7, 0.55, 1.0)
]
const CONFETTI_COLORS = [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.2), Color(0.3, 1.0, 0.5),
	Color(0.3, 0.7, 1.0), Color(0.9, 0.4, 1.0), Color(1.0, 1.0, 1.0)
]
const SPARK_COLORS = [Color(0.3, 0.95, 1.0), Color(0.7, 0.55, 1.0), Color(1.0, 1.0, 1.0)]
const SHATTER_COLORS = [Color(0.95, 0.55, 0.25), Color(0.55, 0.36, 1.0)]
const RAINBOW_TRAIL_COLORS = [
	Color(1.0, 0.4, 0.4), Color(1.0, 0.9, 0.4), Color(0.5, 1.0, 0.5),
	Color(0.4, 0.8, 1.0), Color(0.8, 0.5, 1.0)
]

@onready var _container: Node2D = %Particles

var _pool: Array[Particle] = []
var _active: Array[Particle] = []
var _character: Node2D = null
var _base_modulate: Color = Color.WHITE
var _pulse_tween: Tween
var _flip_tween: Tween
var _glitch_tween: Tween
var _glitch_layer: CanvasLayer
var _glitch_rect: ColorRect
var _trail_left: float = 0.0
var _trail_timer: float = 0.0
var _trail_index: int = 0
var _last_landing_msec: Dictionary = {}
var _connected_ids: Dictionary = {}


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
	var manager: EffectsManager = null

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
		push_error("EffectsManager: missing unique node 'Particles'. Check scenes/Effects.tscn.")
	_build_glitch_overlay()


func _process(delta: float) -> void:
	if _trail_left <= 0.0:
		return
	_trail_left -= delta
	_trail_timer -= delta
	if _trail_timer <= 0.0 and _character != null and is_instance_valid(_character):
		_trail_timer = RAINBOW_TRAIL_INTERVAL
		_spawn_trail_puff(_character.global_position)


## Bind a visual child such as Sprite2D, never the physics body.
func bind_character(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual is PhysicsBody2D:
		push_error("EffectsManager: bind a visual child (e.g. Sprite2D), not the physics body.")
		return
	_character = visual
	_base_modulate = visual.modulate


## Connect once per platform, after adding it to the scene tree.
func connect_platform(platform: Platform) -> void:
	if platform == null or not is_instance_valid(platform):
		return
	var id: int = platform.get_instance_id()
	if _connected_ids.has(id):
		return
	_connected_ids[id] = true
	platform.platform_landed.connect(_on_platform_landed.bind(platform))
	platform.special_effect_triggered.connect(_on_special_effect.bind(platform))
	platform.platform_destroyed.connect(_on_platform_destroyed)


## Stop active effects and restore the character before restarting a run.
func clear_all() -> void:
	for particle in _active.duplicate():
		release_particle(particle)
	_last_landing_msec.clear()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	if _glitch_tween != null and _glitch_tween.is_valid():
		_glitch_tween.kill()
	_trail_left = 0.0
	_set_glitch_intensity(0.0)
	if _glitch_rect != null and is_instance_valid(_glitch_rect):
		_glitch_rect.visible = false
	if _character != null and is_instance_valid(_character):
		_character.modulate = _base_modulate
		_character.rotation = 0.0


## Public trigger API. world_pos is unused by character-only effects.
func trigger(effect_type: StringName, world_pos: Vector2 = Vector2.ZERO) -> void:
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
		&"rainbow_trail":
			start_rainbow_trail()
		&"glitch":
			play_glitch()


func _on_platform_landed(kind: int, landing_position: Vector2, source: Platform) -> void:
	if not _accept_landing(source):
		return
	spawn_sparkle_burst(landing_position)
	match kind:
		Platform.Kind.NORMAL, Platform.Kind.MOVING:
			pulse_character()
		Platform.Kind.CRUMBLE:
			spawn_pixel_emoji(landing_position, 5)
		Platform.Kind.RAINBOW:
			spawn_confetti(landing_position, 40)
			pulse_character()
			flip_character()
			start_rainbow_trail()
		Platform.Kind.GLITCH:
			spawn_pixel_emoji(landing_position, 6)
			pulse_character(Color(0.6, 1.6, 1.0))
		Platform.Kind.MEME:
			spawn_pixel_emoji(landing_position, 8)
			flip_character()


## Handles effects that are not already covered by platform_landed.
func _on_special_effect(effect_type: StringName, effect_position: Vector2, _source: Platform) -> void:
	match effect_type:
		&"crumble_break":
			spawn_shatter(effect_position)
		&"glitch":
			play_glitch()


func _on_platform_destroyed(platform: Platform) -> void:
	if not is_instance_valid(platform):
		return
	var id: int = platform.get_instance_id()
	_last_landing_msec.erase(id)
	_connected_ids.erase(id)


func _accept_landing(source: Platform) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	var id: int = source.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if _last_landing_msec.has(id) and now - _last_landing_msec[id] < LANDING_COOLDOWN_MSEC:
		return false
	_last_landing_msec[id] = now
	return true


## Short burst of glowing sparks around the landing point.
func spawn_sparkle_burst(world_pos: Vector2, count: int = 14) -> void:
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(90.0, 260.0)
		var particle := _make_particle(world_pos, Vector2(cos(angle), sin(angle)) * speed,
			randf_range(0.35, 0.6), SPARK_COLORS[randi() % SPARK_COLORS.size()],
			randf_range(2.0, 3.5), Particle.SHAPE_CIRCLE)
		if particle == null:
			break
		particle.gravity = 180.0


## Pixel-style hearts, stars, bolts, and sparkles that rise then fall.
func spawn_pixel_emoji(world_pos: Vector2, count: int = 6, life: float = 1.2) -> void:
	for i in range(count):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-120.0, 120.0), randf_range(-320.0, -200.0)),
			life * randf_range(0.8, 1.0),
			PIXEL_COLORS[randi() % PIXEL_COLORS.size()],
			3.0, Particle.SHAPE_PIXEL)
		if particle == null:
			break
		particle.pattern = PIXEL_PATTERNS[randi() % PIXEL_PATTERNS.size()]
		particle.gravity = 520.0
		particle.spin = randf_range(-3.0, 3.0)


## Confetti for special landings.
func spawn_confetti(world_pos: Vector2, count: int = 40, life: float = 1.4) -> void:
	for i in range(count):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-260.0, 260.0), randf_range(-420.0, -160.0)),
			life * randf_range(0.7, 1.0),
			CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()],
			4.0, Particle.SHAPE_CONFETTI)
		if particle == null:
			break
		particle.gravity = 700.0
		particle.spin = randf_range(-12.0, 12.0)


## Shards that fly out when a crumble platform breaks.
func spawn_shatter(world_pos: Vector2) -> void:
	for i in range(10):
		var particle := _make_particle(world_pos,
			Vector2(randf_range(-200.0, 200.0), randf_range(-260.0, -60.0)),
			randf_range(0.6, 0.9),
			SHATTER_COLORS[randi() % SHATTER_COLORS.size()],
			4.0, Particle.SHAPE_SQUARE)
		if particle == null:
			break
		particle.gravity = 600.0
		particle.spin = randf_range(-8.0, 8.0)


## Rainbow streak that follows the character for a short time.
func start_rainbow_trail(duration: float = RAINBOW_TRAIL_DURATION) -> void:
	_trail_left = maxf(_trail_left, duration)
	_trail_timer = 0.0


func _spawn_trail_puff(world_pos: Vector2) -> void:
	_trail_index = (_trail_index + 1) % RAINBOW_TRAIL_COLORS.size()
	var particle := _make_particle(world_pos + Vector2(randf_range(-6.0, 6.0), 6.0),
		Vector2(randf_range(-20.0, 20.0), randf_range(30.0, 60.0)),
		0.5, RAINBOW_TRAIL_COLORS[_trail_index], 4.0, Particle.SHAPE_CIRCLE)
	if particle != null:
		particle.gravity = -40.0


## Flash the character tint, then restore its original color.
func pulse_character(flash: Color = Color(1.6, 1.6, 1.6, 1.0), duration: float = 0.18) -> void:
	if _character == null or not is_instance_valid(_character):
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_character.modulate = _base_modulate
	else:
		_base_modulate = _character.modulate
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_character, "modulate", _base_modulate * flash, duration * 0.3)
	_pulse_tween.tween_property(_character, "modulate", _base_modulate, duration * 0.7)


## Spin only the character's visual, leaving its physics body unaffected.
func flip_character(duration: float = 0.45) -> void:
	if _character == null or not is_instance_valid(_character):
		return
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_character.rotation = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(_character, "rotation", TAU, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_callback(_reset_character_rotation)


func _reset_character_rotation() -> void:
	if _character != null and is_instance_valid(_character):
		_character.rotation = 0.0


## Fullscreen glitch overlay. Starting it again replaces the previous tween.
func play_glitch(duration: float = GLITCH_OVERLAY_DURATION) -> void:
	if _glitch_rect == null or not is_instance_valid(_glitch_rect):
		return
	if _glitch_tween != null and _glitch_tween.is_valid():
		_glitch_tween.kill()
	_glitch_rect.visible = true
	_set_glitch_intensity(1.0)
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(_set_glitch_intensity, 1.0, 0.0, duration)
	_glitch_tween.tween_callback(_hide_glitch)


func _hide_glitch() -> void:
	if _glitch_rect != null and is_instance_valid(_glitch_rect):
		_glitch_rect.visible = false


func _set_glitch_intensity(value: float) -> void:
	if _glitch_rect == null or not is_instance_valid(_glitch_rect):
		return
	var material := _glitch_rect.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("intensity", value)


func _build_glitch_overlay() -> void:
	var shader := load(GLITCH_SHADER_PATH) as Shader
	if shader == null:
		push_warning("EffectsManager: glitch shader missing at %s. Glitch overlay disabled." % GLITCH_SHADER_PATH)
		return
	_glitch_layer = CanvasLayer.new()
	_glitch_layer.layer = 5
	add_child(_glitch_layer)

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("intensity", 0.0)

	_glitch_rect = ColorRect.new()
	_glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_rect.material = material
	_glitch_rect.visible = false
	_glitch_layer.add_child(_glitch_rect)


func _make_particle(world_pos: Vector2, velocity: Vector2, life: float, tint: Color,
		radius: float, shape: int) -> Particle:
	if _container == null or not is_instance_valid(_container):
		push_error("EffectsManager: cannot create particles without a valid 'Particles' container.")
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


## Return a finished particle to the pool. Safe to call more than once.
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