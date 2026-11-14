extends Camera2D
class_name FollowCamera

@export var target: Node2D
@export var smooth_speed: float = 8.5

var highest_y: float = 0.0
var shake_intensity: float = 0.0
const SHAKE_DECAY: float = 12.0 # Smooth rapid decay
var drunk_camera_timer: float = 0.0

func _ready() -> void:
	highest_y = global_position.y
	GameState.effect_requested.connect(_on_effect_requested)

func add_shake(amount: float) -> void:
	shake_intensity = clampf(shake_intensity + amount, 0.0, 18.0)

func _on_effect_requested(effect_name: StringName, extra_data: Variant) -> void:
	match effect_name:
		&"shake":
			var p = 6.0
			if extra_data is float or extra_data is int:
				p = float(extra_data)
			add_shake(p)
		&"bounce_shake":
			add_shake(2.2)
		&"spring_shake":
			add_shake(7.5)

func _physics_process(delta: float) -> void:
	# 1. Camera shake decay & offset
	if shake_intensity > 0.05:
		shake_intensity = lerpf(shake_intensity, 0.0, SHAKE_DECAY * delta)
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		shake_intensity = 0.0
		offset = Vector2.ZERO

	# Drunk buff camera tilt sway
	if GameState.is_drunk:
		drunk_camera_timer += delta * 2.2
		rotation = sin(drunk_camera_timer) * 0.024
	else:
		rotation = lerp_angle(rotation, 0.0, 8.0 * delta)

	if not target:
		return
		
	# 2. Camera ONLY moves upward (negative Y)
	# Smoothly follow upward with responsive speed
	if target.global_position.y < global_position.y:
		global_position.y = lerp(global_position.y, target.global_position.y, smooth_speed * delta)
		if global_position.y < highest_y:
			highest_y = global_position.y
			
	# 3. Falling below screen death condition:
	var half_h = get_viewport_rect().size.y / 2.0
	var screen_bottom = global_position.y + half_h
	if target and target.global_position.y > screen_bottom + 15.0:
		if target.has_method("start_falling_abyss_death"):
			target.start_falling_abyss_death()
		elif target.has_method("die"):
			target.die()
		else:
			GameState.end_game()
