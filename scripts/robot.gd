extends CharacterBody2D
class_name Robot

signal bounced(power: float)

@export var gravity: float = 1550.0
@export var steer_speed: float = 760.0
@export var bounce_velocity: float = -960.0
@export var camera: Camera2D
@export var spawner: Node2D

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
var is_falling_death: bool = false
var last_bounce_time: float = -10.0
var drunk_timer: float = 0.0

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
	var base_v: float
	if diff <= 0.0:
		base_v = bounce_velocity
	else:
		var eff_g = get_effective_gravity()
		base_v = -sqrt(2.0 * eff_g * 297.0)
	# Drunk buff: extra soaring bounce power (+10% upward velocity)
	if GameState.is_drunk:
		base_v *= 1.10
	return base_v

func _physics_process(delta: float) -> void:
	if is_falling_death:
		# Custom plummeting physics during extended abyss fall
		velocity.y += (gravity * 1.4) * delta
		position.y += velocity.y * delta
		position.x += velocity.x * delta
		if sprite:
			sprite.rotation += 15.0 * delta
		return
		
	if is_dead:
		return
		
	# 1. Apply progressive gravity
	velocity.y += get_effective_gravity() * delta
	
	# Thruster flame lights up when rocketing upward!
	if thruster:
		thruster.visible = (velocity.y < -120.0)
	
	# 2. Horizontal steering via ui_left and ui_right (Inverted at 500/1000 score!)
	var active_invert = -1.0 if GameState.are_controls_inverted else 1.0
	var direction = Input.get_axis("ui_left", "ui_right") * active_invert * steer_multiplier
	var base_steer = direction * get_effective_steer_speed()
	
	# Drunk buff mechanics: sinusoidal swaying stagger and hilarious wobble
	var drunk_sway = 0.0
	if GameState.is_drunk:
		drunk_timer += delta * 3.8
		drunk_sway = sin(drunk_timer) * 165.0
		
	velocity.x = base_steer + drunk_sway
	
	# Slight tilt animation for steering feedback + drunken wobble
	var target_rotation = 0.0
	if direction != 0:
		target_rotation = direction * 0.15
	if GameState.is_drunk:
		target_rotation += sin(drunk_timer * 1.8) * 0.18
		
	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, 0.2)
	
	# Save pre-slide vertical velocity to detect downward impact
	var was_falling = velocity.y >= 0.0
	
	# 3. Move with physics
	move_and_slide()
	
	# 4. Auto-bounce when touching any platform while falling or at jump apex (forgiving edges & non-level contacts)
	var can_bounce = (was_falling or velocity.y >= -60.0) and not is_dead and not is_falling_death
	if can_bounce:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.has_method("on_robot_landed"):
				collider.on_robot_landed(self)
				break
	
	# 5. Screen boundary handling (wrapping):
	var center_x = get_viewport_rect().size.x / 2.0
	var left_bound = center_x - 270.0
	var right_bound = center_x + 270.0
	if position.x <= left_bound - HALF_WIDTH:
		position.x = right_bound + HALF_WIDTH
	elif position.x >= right_bound + HALF_WIDTH:
		position.x = left_bound - HALF_WIDTH
		
	# 6. Abyss fall check: if falling and no platforms underneath, trigger extended fall death!
	if was_falling and not is_dead:
		var half_h = get_viewport_rect().size.y / 2.0
		var cam_y = camera.global_position.y if camera else global_position.y
		var screen_bottom = cam_y + half_h
		
		# If robot has fallen past visible screen or has no platforms beneath
		if global_position.y > screen_bottom - 20.0:
			var has_platforms = true
			if spawner and spawner.has_method("has_platforms_below"):
				has_platforms = spawner.has_platforms_below(global_position.y)
			else:
				has_platforms = false
				
			if not has_platforms or global_position.y > screen_bottom + 15.0:
				start_falling_abyss_death()

func start_falling_abyss_death() -> void:
	if is_dead:
		return
	is_dead = true
	is_falling_death = true
	
	# Disable collisions immediately so it can NEVER hit anything or bounce
	collision_layer = 0
	collision_mask = 0
	
	# Play the mixkit-falling-male-scream-391 sound!
	GameState.play_falling_scream()
	
	# Extended falling animation: flailing, spinning, shrinking into the void
	velocity.x = randf_range(-60.0, 60.0)
	velocity.y = maxf(velocity.y, 450.0)
	
	var tween = create_tween()
	# Shrink and plunge deep into the dark void over 1.7 seconds
	tween.tween_property(sprite, "scale", Vector2(0.08, 0.08), 1.6)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate", Color(0.1, 0.1, 0.2, 0.2), 1.6)
	
	# End game and show death roast after the extended fall
	var end_timer = get_tree().create_timer(1.75)
	end_timer.timeout.connect(func():
		GameState.trigger_effect(&"shake", 8.0)
		GameState.end_game()
	)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	# Quick death spin & drop + heavy screen shake
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", PI * 2, 0.4)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.4)
	GameState.trigger_effect(&"screen_flash", Color(1.0, 0.2, 0.2, 0.5))
	GameState.trigger_effect(&"shake", 14.0)
	GameState.end_game()

func bounce(multiplier: float = 1.0) -> void:
	if is_dead or is_falling_death:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_bounce_time < 0.10:
		return
	last_bounce_time = current_time
	
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
