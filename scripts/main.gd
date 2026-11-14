extends Node2D

@onready var robot: CharacterBody2D = $Robot
@onready var camera: Camera2D = $Camera2D
@onready var spawner: Node2D = $Spawner
@onready var background_rect: ColorRect = $Background/ColorRect

var can_restart: bool = false
var start_y: float = 450.0

func _ready() -> void:
	GameState.start_game()
	GameState.game_over.connect(_on_game_over)
	GameState.color_scheme_changed.connect(_on_color_scheme_changed)
	
	_on_color_scheme_changed(GameState.color_scheme_index)
	spawner.camera = camera
	camera.target = robot
	start_y = robot.global_position.y

func _physics_process(_delta: float) -> void:
	# Height-based score calculation
	if GameState.is_game_active and is_instance_valid(robot):
		var current_height = maxf(0.0, (start_y - robot.global_position.y) / 8.0)
		GameState.update_score(int(current_height))
		
	# Spacebar restart when game over
	if can_restart and Input.is_action_just_pressed("start_action"):
		_restart_game()

func _on_color_scheme_changed(scheme_index: int) -> void:
	if scheme_index < GameState.COLOR_SCHEMES.size():
		var scheme = GameState.COLOR_SCHEMES[scheme_index]
		if background_rect:
			background_rect.color = scheme["bg"]

func _on_game_over() -> void:
	# Enable instant Space restart
	can_restart = true

func _restart_game() -> void:
	can_restart = false
	get_tree().reload_current_scene()
