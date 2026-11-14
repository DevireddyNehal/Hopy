extends CharacterBody2D

const SPEED: float = 300.0
const NORMAL_BOUNCE: float = -700.0
var steering := PlayerAdapter.SteeringModifier.new()


func _ready() -> void:
	add_to_group("player")


func apply_default_bounce() -> void:
	velocity.y = NORMAL_BOUNCE


func apply_boosted_bounce(velocity_y: float) -> void:
	velocity.y = velocity_y


func apply_steering_modifier(multiplier: float, duration: float) -> void:
	steering.request(multiplier, duration)


func on_platform_landed(_platform_type: int, _landing_position: Vector2) -> void:
	if GameState.is_game_active:
		GameState.increment_combo()


func _physics_process(delta: float) -> void:
	steering.update(delta)
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED * steering.multiplier
	velocity.y += get_gravity().y * delta
	move_and_slide()
	var viewport_width: float = get_viewport_rect().size.x
	if global_position.x < -18.0:
		global_position.x = viewport_width + 18.0
	elif global_position.x > viewport_width + 18.0:
		global_position.x = -18.0
