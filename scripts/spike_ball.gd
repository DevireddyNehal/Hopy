extends Area2D
class_name FloatingSpikeBall

@export var bob_amplitude: float = 14.0
@export var bob_speed: float = 3.2
@export var rotate_speed: float = 2.4

var _initial_y: float = 0.0
var _time: float = 0.0

@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	_initial_y = position.y
	_time = randf_range(0.0, TAU)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_time += delta * bob_speed
	position.y = _initial_y + sin(_time) * bob_amplitude
	if visuals:
		visuals.rotation += rotate_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Robot or body.name == "Robot" or body.has_method("die"):
		GameState.trigger_effect(&"shatter", global_position)
		GameState.trigger_effect(&"screen_flash", Color(1.0, 0.1, 0.1, 0.7))
		GameState.trigger_effect(&"shake", 18.0)
		if body.has_method("die"):
			body.die()
		else:
			GameState.end_game()
