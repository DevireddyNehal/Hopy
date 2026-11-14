extends CharacterBody2D
class_name Robot

signal bounced(power: float)

@export var gravity: float = 1550.0
@export var steer_speed: float = 760.0
@export var bounce_velocity: float = -960.0

@onready var sprite: Node2D = $Visuals
@onready var effect_spawn_point: Marker2D = $EffectSpawnPoint
@onready var thruster: Polygon2D = $Visuals/ThrusterFlame

const BASE_SCALE: Vector2 = Vector2(1.35, 1.35)
const HALF_WIDTH: float = 25.0 # half robot width for clean wrapping

# Multiplier applied when special platforms (like Rainbow) boost the bounce
var current_bounce_multiplier: float = 1.0

# Steering multiplier
var steer_multiplier: float = 1.0
var is_dead: bool = false

func _ready() -> void:
	# Initialize base scale
	sprite.scale = BASE_SCALE
	# Launch upward on start/restart like classic Doodle Jump!
	velocity.y = bounce_velocity
	_play_squash_and_stretch()

func get_effective_gravity() -> float:
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	return gravity + (diff * 280.0)

func get_effective_steer_speed() -> float:
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	return steer_speed + (diff * 180.0)

func get_effective_bounce_velocity() -> float:
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	if diff <= 0.0:
		return bounce_velocity
	var eff_g = get_effective_gravity()
	return -sqrt(2.0 * eff_g * 297.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# 1. Apply progressive gravity
	velocity.y += get_effective_gravity() * delta
	
	# Thruster flame lights up when rocketing upward!
	if thruster:
		thruster.visible = (velocity.y < -120.0)
	
	# 2. Horizontal steering via ui_left and ui_right (Left/Right arrows and A/D)
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * get_effective_steer_speed() * steer_multiplier
	
	# Slight tilt animation for steering feedback
	if direction != 0:
		sprite.rotation = lerp_angle(sprite.rotation, direction * 0.15, 0.2)
	else:
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 0.2)
	
	# Save pre-slide vertical velocity to detect downward impact
	var was_falling = velocity.y >= 0.0
	
	# 3. Move with physics
	move_and_slide()
	
	# 4. Auto-bounce when landing on a floor/platform while falling
	if is_on_floor() and was_falling:
		var handled_by_platform = false
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			# Normal pointing up check (so side brushes don't trigger bounce)
			if collision.get_normal().y < -0.5:
				if collider and collider.has_method("on_robot_landed"):
					collider.on_robot_landed(self)
					handled_by_platform = true
					break
		if not handled_by_platform:
			bounce(1.0)
	
	# 5. Screen boundary handling:
	# Choice: SCREEN WRAPPING. Exiting the left edge wraps the robot to the right edge,
	# and exiting the right edge wraps the robot to the left edge.
	var screen_width = get_viewport_rect().size.x
	if position.x <= -HALF_WIDTH:
		position.x = screen_width + HALF_WIDTH
	elif position.x >= screen_width + HALF_WIDTH:
		position.x = -HALF_WIDTH

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	# Quick death spin & drop + heavy screen shake
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", PI * 2, 0.4)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.4)
	GameState.trigger_effect(&"screen_flash", Color(1.0, 0.2, 0.2, 0.5))
	GameState.trigger_effect(&"shake", 14.0)
	GameState.end_game()

func bounce(multiplier: float = 1.0) -> void:
	if is_dead:
		return
	current_bounce_multiplier = multiplier
	velocity.y = get_effective_bounce_velocity() * current_bounce_multiplier
	
	# Notify GameState combo tracker & audio
	GameState.increment_combo()
	GameState.play_bounce()
	bounced.emit(current_bounce_multiplier)
	
	# Visual landing effects: sparkles at feet + character pulse + subtle camera micro-shake
	GameState.trigger_effect(&"sparkle", global_position + Vector2(0, 16))
	GameState.trigger_effect(&"pulse")
	GameState.trigger_effect(&"bounce_shake")
	
	# Quick squash & stretch bounce animation
	_play_squash_and_stretch()

func _play_squash_and_stretch() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(1.25, 0.75), 0.05)
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(0.88, 1.15), 0.1)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.1)
