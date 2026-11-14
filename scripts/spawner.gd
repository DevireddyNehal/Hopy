extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: comfortable, dense, reachable climb
const MIN_GAP_Y: float = 80.0
const MAX_GAP_Y: float = 135.0
const BUFFER_AHEAD: float = 1200.0 # Keep spawning 1200px above camera
const DESPAWN_OFFSET: float = 600.0 # Remove platforms 600px below camera

var highest_spawned_y: float = 520.0
var platform_count: int = 0
var last_spawned_x: float = 960.0
var active_platforms: Array[StaticBody2D] = []

func _ready() -> void:
	if not platform_scene:
		platform_scene = preload("res://scenes/Platform.tscn")
	var screen_w = get_viewport_rect().size.x
	last_spawned_x = screen_w / 2.0
	# Initial seed platforms
	_spawn_initial_platforms()

func _physics_process(_delta: float) -> void:
	if not camera:
		return
		
	var half_h = get_viewport_rect().size.y / 2.0
	# 1. Spawn ahead of camera
	var camera_top = camera.global_position.y - half_h
	while highest_spawned_y > camera_top - BUFFER_AHEAD:
		_spawn_next_platform()
		
	# 2. Cleanup platforms that fall below screen
	var camera_bottom = camera.global_position.y + half_h + DESPAWN_OFFSET
	_cleanup_old_platforms(camera_bottom)

func _spawn_initial_platforms() -> void:
	var screen_w = get_viewport_rect().size.x
	var center_x = screen_w / 2.0
	# First safe platform directly under the player start
	_spawn_platform_at(Vector2(center_x, 520), PlatformScript.Type.NORMAL)
	
	# Spawn a trail of initial platforms reaching up
	for i in range(16):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	highest_spawned_y -= gap
	
	var screen_w = get_viewport_rect().size.x
	var min_x = 80.0
	var max_x = screen_w - 80.0
	
	# Reachable horizontal range rule:
	# With steer_speed = 520, reach is >500px, so +-360px guarantees it is always reachable!
	var offset_x = randf_range(-360.0, 360.0)
	var spawn_x = clampf(last_spawned_x + offset_x, min_x, max_x)
	last_spawned_x = spawn_x
	
	platform_count += 1
	var chosen_type = PlatformScript.Type.NORMAL
	
	# Special platform appears about once every 8 to 10 platforms (12% chance)
	if platform_count > 3 and randf() < 0.15:
		var specials = [
			PlatformScript.Type.MOVING,
			PlatformScript.Type.CRUMBLE,
			PlatformScript.Type.RAINBOW,
			PlatformScript.Type.THORN,
			PlatformScript.Type.MEME
		]
		chosen_type = specials[randi() % specials.size()]
		
	_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), chosen_type)

func _spawn_platform_at(pos: Vector2, type: int) -> void:
	var plat = platform_scene.instantiate()
	plat.global_position = pos
	plat.platform_type = type
	add_child(plat)
	active_platforms.append(plat)

func _cleanup_old_platforms(threshold_y: float) -> void:
	var surviving: Array[StaticBody2D] = []
	for plat in active_platforms:
		if is_instance_valid(plat):
			if plat.global_position.y > threshold_y:
				plat.queue_free()
			else:
				surviving.append(plat)
	active_platforms = surviving
