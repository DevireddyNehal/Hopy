extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: 95px - 145px (apex is 289px, so you have 144px leeway!)
const MIN_GAP_Y: float = 95.0
const MAX_GAP_Y: float = 145.0
const BUFFER_AHEAD: float = 1200.0
const DESPAWN_OFFSET: float = 600.0

var highest_spawned_y: float = 520.0
var platform_count: int = 0
var last_x: float = 576.0
var active_platforms: Array[StaticBody2D] = []

func _ready() -> void:
	if not platform_scene:
		platform_scene = preload("res://scenes/Platform.tscn")
	var screen_w = get_viewport_rect().size.x
	last_x = screen_w / 2.0
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
	
	highest_spawned_y = center_y + 180.0
	last_x = center_x
	
	# 1. Guaranteed first safe landing platform directly underneath the robot (2.5x wide!)
	var start_plat = _spawn_platform_at(Vector2(center_x, highest_spawned_y), PlatformScript.Type.NORMAL)
	if start_plat:
		start_plat.scale = Vector2(2.5, 1.0)
	
	# 2. Pre-spawn a trail of platforms climbing upward
	for i in range(16):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	highest_spawned_y -= gap
	
	var screen_w = get_viewport_rect().size.x
	var min_x = 90.0
	var max_x = screen_w - 90.0
	
	# Guaranteed reach rule:
	# Each platform is within +-340px of the last one.
	# (With steer_speed=650 and air_time=1.28s, travel is 832px -> massive 492px leeway!)
	var offset_x = randf_range(-340.0, 340.0)
	if abs(offset_x) < 80.0:
		offset_x = 100.0 if offset_x >= 0 else -100.0
		
	var spawn_x = last_x + offset_x
	if spawn_x < min_x:
		spawn_x = max_x - (min_x - spawn_x)
	elif spawn_x > max_x:
		spawn_x = min_x + (spawn_x - max_x)
	last_x = spawn_x
	
	_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), _pick_type())
	
	# 40% chance to spawn an alternate platform on the other side for route variety:
	if randf() < 0.4:
		var alt_x = fposmod(spawn_x + randf_range(400.0, screen_w - 400.0), screen_w - 180.0) + 90.0
		_spawn_platform_at(Vector2(alt_x, highest_spawned_y + randf_range(-15.0, 15.0)), _pick_type())

func _pick_type() -> int:
	platform_count += 1
	var chosen_type = PlatformScript.Type.NORMAL
	
	# Special platform appears about once every 8 to 10 platforms (12% chance)
	if platform_count > 3 and randf() < 0.14:
		var specials = [
			PlatformScript.Type.MOVING,
			PlatformScript.Type.CRUMBLE,
			PlatformScript.Type.RAINBOW,
			PlatformScript.Type.THORN,
			PlatformScript.Type.MEME
		]
		chosen_type = specials[randi() % specials.size()]
	return chosen_type

func _spawn_platform_at(pos: Vector2, type: int) -> StaticBody2D:
	var plat = platform_scene.instantiate()
	plat.global_position = pos
	plat.platform_type = type
	add_child(plat)
	active_platforms.append(plat)
	return plat

func _cleanup_old_platforms(threshold_y: float) -> void:
	var surviving: Array[StaticBody2D] = []
	for plat in active_platforms:
		if is_instance_valid(plat):
			if plat.global_position.y > threshold_y:
				plat.queue_free()
			else:
				surviving.append(plat)
	active_platforms = surviving
