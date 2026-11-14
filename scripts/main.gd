extends Node2D

@onready var robot: CharacterBody2D = $Robot
@onready var camera: Camera2D = $Camera2D
@onready var spawner: Node2D = $Spawner
@onready var background_rect: ColorRect = $Background/ColorRect
@onready var effects: Node2D = $Effects

var can_restart: bool = false
var start_y: float = 450.0

func _ready() -> void:
	GameState.start_game()
	GameState.game_over.connect(_on_game_over)
	GameState.color_scheme_changed.connect(_on_color_scheme_changed)
	
	_on_color_scheme_changed(GameState.color_scheme_index)
	spawner.camera = camera
	camera.target = robot
	
	if effects and effects.has_method("bind_character") and robot.has_node("Visuals"):
		effects.bind_character(robot.get_node("Visuals"))
	
	# Dynamically center robot & camera for any resolution (1080p, 1440p, fullscreen)
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2.0
	var center_y = screen_size.y / 2.0
	
	camera.global_position = Vector2(center_x, center_y)
	robot.global_position = Vector2(center_x, center_y + 80.0)
	start_y = robot.global_position.y

func _physics_process(_delta: float) -> void:
	# Height-based score calculation
	if GameState.is_game_active and is_instance_valid(robot):
		var current_height = maxf(0.0, (start_y - robot.global_position.y) / 8.0)
		GameState.update_score(int(current_height))
		
func _on_color_scheme_changed(scheme_index: int) -> void:
	if scheme_index < GameState.COLOR_SCHEMES.size():
		var scheme = GameState.COLOR_SCHEMES[scheme_index]
		if background_rect:
			var tween = create_tween()
			tween.tween_property(background_rect, "color", scheme["bg"], 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_game_over() -> void:
	pass
