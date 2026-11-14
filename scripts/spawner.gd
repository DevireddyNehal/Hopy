extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var camera: Camera2D

# Max jump height is 175px (v=700, g=1400), so gap must always be <= 160px
const MIN_GAP_Y: float = 85.0
const MAX_GAP_Y: float = 145.0
const MIN_X: float = 80.0
const MAX_X: float = 1072.0
const BUFFER_AHEAD: float = 800.0 # Keep spawning 800px above camera
const DESPAWN_OFFSET: float = 500.0 # Remove platforms 500px below camera

var highest_spawned_y: float = 520.0
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
		
	# 1. Spawn ahead of camera
	var camera_top = camera.global_position.y - 324.0
	while highest_spawned_y > camera_top - BUFFER_AHEAD:
		_spawn_next_platform()
		
	# 2. Cleanup platforms that fall below screen
	var camera_bottom = camera.global_position.y + 324.0 + DESPAWN_OFFSET
	_cleanup_old_platforms(camera_bottom)

func _spawn_initial_platforms() -> void:
	# First safe platform directly under the player start
	_spawn_platform_at(Vector2(576, 520), PlatformScript.Type.NORMAL)
	
	# Spawn a trail of initial platforms reaching up
	for i in range(12):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	highest_spawned_y -= gap
	var spawn_x = randf_range(MIN_X, MAX_X)
	
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
