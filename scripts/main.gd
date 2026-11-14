extends Node2D

@onready var robot: CharacterBody2D = $Robot
@onready var camera: Camera2D = $Camera2D
@onready var spawner: Node2D = $Spawner
@onready var background_rect: ColorRect = $Background/PlayfieldRect if has_node("Background/PlayfieldRect") else $Background/ColorRect
@onready var effects: Node2D = $Effects
@onready var star_particles: CPUParticles2D = $Background/StarParticles if has_node("Background/StarParticles") else null
@onready var star_particles_right: CPUParticles2D = $Background/StarParticlesRight if has_node("Background/StarParticlesRight") else null

var can_restart: bool = false
var start_y: float = 450.0
var _last_particles_screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	GameState.start_game()
	GameState.game_over.connect(_on_game_over)
	GameState.color_scheme_changed.connect(_on_color_scheme_changed)
	
	_on_color_scheme_changed(GameState.color_scheme_index)
	spawner.camera = camera
	robot.camera = camera
	robot.spawner = spawner
	camera.target = robot
	
	# Start game audio: "Chaliye shuru karte hain!"
	GameState.play_start_game()
	
	if effects and effects.has_method("bind_character") and robot.has_node("Visuals"):
		effects.bind_character(robot.get_node("Visuals"))
	
	# Dynamically center robot & camera for any resolution (1080p, 1440p, fullscreen)
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2.0
	var center_y = screen_size.y / 2.0
	
	camera.global_position = Vector2(center_x, center_y)
	robot.global_position = Vector2(center_x, center_y + 80.0)
	start_y = robot.global_position.y
	
	get_tree().root.size_changed.connect(_update_star_particles_layout)
	_update_star_particles_layout()

func _process(_delta: float) -> void:
	var curr_size = get_viewport_rect().size
	if curr_size != _last_particles_screen_size:
		_last_particles_screen_size = curr_size
		_update_star_particles_layout()

func _update_star_particles_layout() -> void:
	var screen_size = get_viewport_rect().size
	var center_y = screen_size.y / 2.0
	var count = int(clampf(24.0 * (screen_size.x / 540.0), 20.0, 60.0))
	
	if star_particles and is_instance_valid(star_particles):
		star_particles.visible = true
		star_particles.position = Vector2(screen_size.x * 0.25, center_y)
		star_particles.emission_rect_extents = Vector2(screen_size.x * 0.25, center_y)
		star_particles.amount = count
		
	if star_particles_right and is_instance_valid(star_particles_right):
		star_particles_right.visible = true
		star_particles_right.position = Vector2(screen_size.x * 0.75, center_y)
		star_particles_right.emission_rect_extents = Vector2(screen_size.x * 0.25, center_y)
		star_particles_right.amount = count

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
