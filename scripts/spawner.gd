extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: comfortable, dense, reachable climb
const MIN_GAP_Y: float = 75.0
const MAX_GAP_Y: float = 125.0
const BUFFER_AHEAD: float = 1400.0 # Keep spawning well above camera
const DESPAWN_OFFSET: float = 700.0 # Remove platforms below camera

var highest_spawned_y: float = 700.0
var platform_count: int = 0
var active_platforms: Array[StaticBody2D] = []

func _ready() -> void:
	if not platform_scene:
		platform_scene = preload("res://scenes/Platform.tscn")
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
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2.0
	var center_y = screen_size.y / 2.0
	
	highest_spawned_y = center_y + 200.0
	
	# 1. Guaranteed first safe landing platform directly underneath the robot
	_spawn_platform_at(Vector2(center_x, highest_spawned_y), PlatformScript.Type.NORMAL)
	
	# 2. Pre-spawn a dense trail of platforms climbing upward across the screen
	for i in range(25):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	highest_spawned_y -= gap
	
	var screen_w = get_viewport_rect().size.x
	
	# Platform 1: Distributed across the screen
	var spawn_x = randf_range(100.0, screen_w - 100.0)
	_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), _pick_type())
	
	# Platform 2 (Widescreen coverage):
	# 60% chance to spawn an alternate platform on the opposite side of the screen
	# so the 1920 widescreen is never empty on either flank!
	if randf() < 0.65:
		var second_x: float
		if spawn_x < screen_w / 2.0:
			second_x = randf_range(screen_w / 2.0 + 80.0, screen_w - 100.0)
		else:
			second_x = randf_range(100.0, screen_w / 2.0 - 80.0)
		var jitter_y = highest_spawned_y + randf_range(-15.0, 15.0)
		_spawn_platform_at(Vector2(second_x, jitter_y), _pick_type())

func _pick_type() -> int:
	platform_count += 1
	var chosen_type = PlatformScript.Type.NORMAL
	
	# Special platform appears about once every 8 to 10 platforms (12% chance)
	if platform_count > 4 and randf() < 0.15:
		var specials = [
			PlatformScript.Type.MOVING,
			PlatformScript.Type.CRUMBLE,
			PlatformScript.Type.RAINBOW,
			PlatformScript.Type.THORN,
			PlatformScript.Type.MEME
		]
		chosen_type = specials[randi() % specials.size()]
	return chosen_type

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
