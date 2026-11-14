extends CharacterBody2D
class_name Robot

signal bounced(power: float)

@export var gravity: float = 1400.0
@export var steer_speed: float = 650.0
@export var bounce_velocity: float = -900.0

@onready var sprite: Node2D = $Visuals
@onready var effect_spawn_point: Marker2D = $EffectSpawnPoint

const HALF_WIDTH: float = 16.0 # half robot width for clean wrapping

# Multiplier applied when special platforms (like Rainbow) boost the bounce
var current_bounce_multiplier: float = 1.0

# Steering multiplier
var steer_multiplier: float = 1.0
var is_dead: bool = false

func _ready() -> void:
	# Launch upward on start/restart like classic Doodle Jump!
	velocity.y = bounce_velocity
	_play_squash_and_stretch()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# 1. Apply gravity
	velocity.y += gravity * delta
	
	# 2. Horizontal steering via ui_left and ui_right (Left/Right arrows and A/D)
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * steer_speed * steer_multiplier
	
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
	if position.x < -HALF_WIDTH:
		position.x = screen_width + HALF_WIDTH
	elif position.x > screen_width + HALF_WIDTH:
		position.x = -HALF_WIDTH

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	# Quick death spin & drop
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", PI * 2, 0.4)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.4)
	GameState.end_game()

func bounce(multiplier: float = 1.0) -> void:
	if is_dead:
		return
	current_bounce_multiplier = multiplier
	velocity.y = bounce_velocity * current_bounce_multiplier
	
	# Notify GameState combo tracker & audio
	GameState.increment_combo()
	GameState.play_bounce()
	bounced.emit(current_bounce_multiplier)
	
	# Quick squash & stretch bounce animation
	_play_squash_and_stretch()

func _play_squash_and_stretch() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
