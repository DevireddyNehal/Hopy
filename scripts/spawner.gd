extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: 120px - 175px (apex is 297px with v=-960 and g=1550)
const MIN_GAP_Y: float = 125.0
const MAX_GAP_Y: float = 175.0
const BUFFER_AHEAD: float = 750.0
const DESPAWN_OFFSET: float = 160.0

var highest_spawned_y: float = 520.0
var platform_count: int = 0
var last_x: float = 270.0
var active_platforms: Array[StaticBody2D] = []

func _ready() -> void:
	if not platform_scene:
		platform_scene = preload("res://scenes/Platform.tscn")
	var screen_w = get_viewport_rect().size.x
	last_x = screen_w / 2.0
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
	
	# 1. Guaranteed safe starter platform directly underneath the robot (generous runway)
	var start_plat = _spawn_platform_at(Vector2(center_x, highest_spawned_y), PlatformScript.Type.NORMAL, Vector2(1.6, 1.0))
	
	# 2. Pre-spawn a lively trail of platforms climbing upward (10 platforms)
	for i in range(10):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	platform_count += 1
	var chosen_type = _pick_type()
	
	# Gap pacing based on platform type
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	if chosen_type == PlatformScript.Type.CRUMBLE:
		gap = randf_range(115.0, 145.0) # Faster rapid hops for crumbles
	elif chosen_type == PlatformScript.Type.RAINBOW:
		gap = randf_range(140.0, 175.0)
	highest_spawned_y -= gap
	
	var screen_w = get_viewport_rect().size.x
	var min_x = 90.0
	var max_x = screen_w - 90.0
	
	# --- Strategic Placement Patterns ---
	var spawn_x: float = center_biased_placement(screen_w, min_x, max_x)
	last_x = spawn_x
	
	# --- Strategic Sizing (Smaller platforms & precision ledges) ---
	var plat_scale = Vector2(1.0, 1.0)
	if platform_count > 8:
		var size_roll = randf()
		if size_roll < 0.35:
			# Compact Precision Ledge (~66px wide)
			plat_scale = Vector2(0.75, 1.0)
		elif size_roll < 0.65:
			# Agile Ledge (~75px wide)
			plat_scale = Vector2(0.85, 1.0)
		else:
			# Standard Ledge (~88px wide)
			plat_scale = Vector2(1.0, 1.0)
	
	_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), chosen_type, plat_scale)

func center_biased_placement(screen_w: float, min_x: float, max_x: float) -> float:
	var pattern_roll = randf()
	var center = screen_w / 2.0
	
	# Pattern A (48%): Dynamic Cross-Screen Zig-Zag (forces left-to-right crossing)
	if pattern_roll < 0.48:
		if last_x < center:
			# Last was left -> Jump over to right half
			return randf_range(center + 40.0, max_x)
		else:
			# Last was right -> Jump over to left half
			return randf_range(min_x, center - 40.0)
			
	# Pattern B (22%): Screen-Wrap Temptation
	elif pattern_roll < 0.70:
		if last_x < center:
			# Spawn far right, encouraging screen wrap through the left wall
			return randf_range(max_x - 45.0, max_x)
		else:
			# Spawn far left, encouraging screen wrap through the right wall
			return randf_range(min_x, min_x + 45.0)
			
	# Pattern C (30%): Center Corridor
	else:
		return randf_range(center - 75.0, center + 75.0)

func _pick_type() -> int:
	# Intro platforms: mostly normal with early taste of moving
	if platform_count <= 3:
		return PlatformScript.Type.NORMAL
	if platform_count == 4:
		return PlatformScript.Type.MOVING
		
	# Beyond platform 4: High stakes & heavy dynamic variety (68% specials!)
	var r = randf()
	if r < 0.30:
		# 30% MOVING: sliding platforms patrol and sweep horizontally
		return PlatformScript.Type.MOVING
	elif r < 0.48:
		# 18% CRUMBLE: single-use breakaway platforms prevent camping
		return PlatformScript.Type.CRUMBLE
	elif r < 0.60:
		# 12% RAINBOW / SPRING: thrilling 1.5x super-bounce rockets
		return PlatformScript.Type.RAINBOW
	elif r < 0.68:
		# 8% THORN HAZARDS: must steer around and dodge!
		return PlatformScript.Type.THORN
	elif r < 0.75:
		# 7% MEME: sound bite & popup
		return PlatformScript.Type.MEME
	else:
		# 25% NORMAL: solid rest platforms
		return PlatformScript.Type.NORMAL

func _spawn_platform_at(pos: Vector2, type: int, custom_scale: Vector2 = Vector2.ONE) -> StaticBody2D:
	var plat = platform_scene.instantiate()
	plat.global_position = pos
	plat.platform_type = type
	plat.scale = custom_scale
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
