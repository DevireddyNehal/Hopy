extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var spike_ball_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: 125px - 175px (apex jump reach is 297px)
const MIN_GAP_Y: float = 125.0
const MAX_GAP_Y: float = 175.0
const BUFFER_AHEAD: float = 750.0
const DESPAWN_OFFSET: float = 160.0

var highest_spawned_y: float = 520.0
var platform_count: int = 0
var last_x: float = 270.0
var active_platforms: Array[StaticBody2D] = []
var active_spike_balls: Array[Area2D] = []

func _ready() -> void:
	if not platform_scene:
		platform_scene = preload("res://scenes/Platform.tscn")
	if not spike_ball_scene and ResourceLoader.exists("res://scenes/SpikeBall.tscn"):
		spike_ball_scene = load("res://scenes/SpikeBall.tscn")
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
	var center = screen_w / 2.0
	var min_x = center - 270.0 + 90.0
	var max_x = center + 270.0 - 90.0
	
	# --- Strategic Placement Patterns ---
	var spawn_x: float = center_biased_placement(screen_w, min_x, max_x)
	
	# --- Strategic Sizing (Progressively smaller at higher scores) ---
	var plat_scale = Vector2(1.0, 1.0)
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	if platform_count > 6:
		var size_roll = randf()
		if size_roll < 0.25 + (diff * 0.25):
			# Compact Precision Ledge (~64px wide)
			plat_scale = Vector2(0.72, 1.0)
		elif size_roll < 0.60 + (diff * 0.20):
			# Agile Ledge (~75px wide)
			plat_scale = Vector2(0.85, 1.0)
		else:
			# Standard Ledge (~88px wide)
			plat_scale = Vector2(1.0, 1.0)
	
	# --- GUARANTEED REACH RULE FOR SPIKES ---
	# Spikes MUST NEVER be in the middle of platforms or on the player's natural path!
	# The SAFE platform is placed at spawn_x (the natural destination), while the Thorn
	# hazard is placed on the opposite flank with generous clearance (>= 130px).
	if chosen_type == PlatformScript.Type.THORN:
		# 1. Spawn guaranteed safe companion platform at spawn_x (natural path target)
		var safe_type = PlatformScript.Type.MOVING if randf() < 0.45 else PlatformScript.Type.NORMAL
		_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), safe_type, plat_scale)
		
		# 2. Spawn Thorn hazard obstacle on opposite flank leaving wide breathing room
		var thorn_x: float
		if spawn_x < center:
			thorn_x = randf_range(center + 55.0, max_x)
		else:
			thorn_x = randf_range(min_x, center - 55.0)
			
		if absf(thorn_x - spawn_x) < 130.0:
			thorn_x = (center + 115.0) if spawn_x < center else (center - 115.0)
			
		_spawn_platform_at(Vector2(thorn_x, highest_spawned_y), PlatformScript.Type.THORN, plat_scale)
		
		# Next platform upward is calculated from the SAFE platform position!
		last_x = spawn_x
	else:
		_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), chosen_type, plat_scale)
		last_x = spawn_x
		
	# --- Floating Spike Ball Hazard Spawn ---
	# Never spawn in the middle of the platform gap or on the player's natural trajectory!
	# Placed on outer flanks or overshoot zones with safe clearance, so clean jumps are safe
	# but player mistakes (oversteering, panicking, reckless wraps) are penalized.
	if platform_count > 6 and chosen_type != PlatformScript.Type.THORN and spike_ball_scene:
		var spike_chance = 0.14 + (diff * 0.12) # 14% -> 26%
		if randf() < spike_chance:
			var ball_pos = _calculate_safe_hazard_position(last_x, spawn_x, highest_spawned_y, gap, screen_w, min_x, max_x)
			if ball_pos != Vector2.ZERO:
				_spawn_spike_ball_at(ball_pos)

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
		
	# Progressive difficulty: moving and crumble platforms become more frequent as score climbs
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	var r = randf()
	var moving_chance = 0.28 + (diff * 0.10) # 28% -> 38%
	var crumble_chance = 0.18 + (diff * 0.08) # 18% -> 26%
	var spring_chance = 0.12 # 12%
	var thorn_chance = 0.08 + (diff * 0.04) # 8% -> 12%
	var meme_chance = 0.06 # 6%
	
	if r < moving_chance:
		return PlatformScript.Type.MOVING
	elif r < moving_chance + crumble_chance:
		return PlatformScript.Type.CRUMBLE
	elif r < moving_chance + crumble_chance + spring_chance:
		return PlatformScript.Type.RAINBOW
	elif r < moving_chance + crumble_chance + spring_chance + thorn_chance:
		return PlatformScript.Type.THORN
	elif r < moving_chance + crumble_chance + spring_chance + thorn_chance + meme_chance:
		return PlatformScript.Type.MEME
	else:
		return PlatformScript.Type.NORMAL

func _spawn_platform_at(pos: Vector2, type: int, custom_scale: Vector2 = Vector2.ONE) -> StaticBody2D:
	var plat = platform_scene.instantiate()
	plat.global_position = pos
	plat.platform_type = type
	plat.scale = custom_scale
	add_child(plat)
	active_platforms.append(plat)
	return plat

func _spawn_spike_ball_at(pos: Vector2) -> Area2D:
	var sb = spike_ball_scene.instantiate()
	sb.global_position = pos
	add_child(sb)
	active_spike_balls.append(sb)
	return sb

func _calculate_safe_hazard_position(from_x: float, to_x: float, top_y: float, gap: float, screen_w: float, min_x: float, max_x: float) -> Vector2:
	var center = screen_w / 2.0
	var ball_x: float
	var ball_y: float
	
	# Determine horizontal jump direction:
	var jumping_right = to_x > from_x + 35.0
	var jumping_left = to_x < from_x - 35.0
	
	var placement_roll = randf()
	
	if jumping_right:
		# Player leaping left-to-right: natural path curves through center.
		# Middle is strictly preserved. Hazard placed on overshoot flank or far rear flank.
		if placement_roll < 0.65:
			# Pattern 1: Overshoot trap past the target platform
			# If player oversteers past to_x to the right, they hit the spike
			ball_x = to_x + randf_range(85.0, 115.0)
			ball_x = clampf(ball_x, to_x + 75.0, max_x + 30.0)
			ball_y = top_y + randf_range(-10.0, 25.0)
		else:
			# Pattern 2: Far left rear flank (behind the takeoff point)
			ball_x = from_x - randf_range(85.0, 115.0)
			ball_x = clampf(ball_x, min_x - 30.0, from_x - 75.0)
			ball_y = top_y + (gap * 0.35)
	elif jumping_left:
		# Player leaping right-to-left: natural path curves through center.
		if placement_roll < 0.65:
			# Pattern 1: Overshoot trap past the target platform
			# If player oversteers past to_x to the left, they hit the spike
			ball_x = to_x - randf_range(85.0, 115.0)
			ball_x = clampf(ball_x, min_x - 30.0, to_x - 75.0)
			ball_y = top_y + randf_range(-10.0, 25.0)
		else:
			# Pattern 2: Far right rear flank (behind the takeoff point)
			ball_x = from_x + randf_range(85.0, 115.0)
			ball_x = clampf(ball_x, from_x + 75.0, max_x + 30.0)
			ball_y = top_y + (gap * 0.35)
	else:
		# Vertical corridor jump (from_x and to_x roughly aligned)
		# Place on the opposite empty half of the screen
		if to_x < center:
			ball_x = randf_range(center + 65.0, max_x)
		else:
			ball_x = randf_range(min_x, center - 65.0)
		ball_y = top_y + (gap * 0.3)
		
	# Strict validation: Ensure hazard is NEVER inside the natural jump corridor
	var corridor_min = minf(from_x, to_x) - 50.0
	var corridor_max = maxf(from_x, to_x) + 50.0
	if ball_x >= corridor_min and ball_x <= corridor_max:
		# In case it lands in corridor, shift it to the outer flank
		if to_x < center:
			ball_x = max_x - 20.0
		else:
			ball_x = min_x + 20.0
			
	# Ensure safe distance from target platform
	if absf(ball_x - to_x) < 70.0:
		return Vector2.ZERO # Skip if too close to platform
		
	return Vector2(ball_x, ball_y)

func _cleanup_old_platforms(threshold_y: float) -> void:
	var surviving: Array[StaticBody2D] = []
	for plat in active_platforms:
		if is_instance_valid(plat):
			# If platform falls below visible screen, disable its collision shape
			# so robot can NEVER hit or bounce off it when falling!
			if plat.global_position.y > threshold_y - DESPAWN_OFFSET:
				if plat.has_node("CollisionShape2D"):
					plat.get_node("CollisionShape2D").set_deferred("disabled", true)
				
			if plat.global_position.y > threshold_y:
				plat.queue_free()
			else:
				surviving.append(plat)
	active_platforms = surviving
	
	var surviving_balls: Array[Area2D] = []
	for ball in active_spike_balls:
		if is_instance_valid(ball):
			if ball.global_position.y > threshold_y:
				ball.queue_free()
			else:
				surviving_balls.append(ball)
	active_spike_balls = surviving_balls

func has_platforms_below(check_y: float) -> bool:
	for plat in active_platforms:
		if is_instance_valid(plat) and not plat.is_broken:
			if plat.global_position.y > check_y:
				return true
	return false
