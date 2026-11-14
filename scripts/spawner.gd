extends Node2D
class_name PlatformSpawner

const PlatformScript = preload("res://scripts/platform.gd")

@export var platform_scene: PackedScene
@export var spike_ball_scene: PackedScene
@export var camera: Camera2D

# Vertical gap limits: 100px - 145px (apex jump reach is 297px - very forgiving)
const MIN_GAP_Y: float = 100.0
const MAX_GAP_Y: float = 145.0
const BUFFER_AHEAD: float = 750.0
const DESPAWN_OFFSET: float = 160.0

var highest_spawned_y: float = 520.0
var platform_count: int = 0
var last_x: float = 270.0
var active_platforms: Array[StaticBody2D] = []
var active_spike_balls: Array[Area2D] = []
var platforms_since_last_spike: int = 10

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
	
	# 2. Pre-spawn a lively trail of platforms climbing upward (12 platforms)
	for i in range(12):
		_spawn_next_platform()

func _spawn_next_platform() -> void:
	platform_count += 1
	var chosen_type = _pick_type()
	
	# Gap pacing based on platform type (forgiving close gaps)
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	if chosen_type == PlatformScript.Type.CRUMBLE:
		gap = randf_range(90.0, 120.0) # Gentle rapid hops for crumbles
	elif chosen_type == PlatformScript.Type.RAINBOW:
		gap = randf_range(115.0, 140.0)
	highest_spawned_y -= gap
	
	var screen_w = get_viewport_rect().size.x
	var center = screen_w / 2.0
	var min_x = center - 270.0 + 90.0
	var max_x = center + 270.0 - 90.0
	
	# --- Strategic Placement Patterns ---
	var spawn_x: float = center_biased_placement(screen_w, min_x, max_x)
	
	# --- Generous Platform Sizing ---
	var plat_scale = Vector2(1.0, 1.0)
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	if platform_count > 6:
		var size_roll = randf()
		if size_roll < 0.15 + (diff * 0.15):
			# Mildly compact (~95px wide)
			plat_scale = Vector2(0.95, 1.0)
		elif size_roll < 0.40:
			# Extra generous ledge (~115px wide)
			plat_scale = Vector2(1.10, 1.0)
		else:
			# Standard (~104px wide)
			plat_scale = Vector2(1.0, 1.0)
	
	# --- GUARANTEED REACH RULE FOR SPIKES ---
	if chosen_type == PlatformScript.Type.THORN:
		# 1. Spawn guaranteed safe companion platform at spawn_x (natural path target)
		var safe_type = PlatformScript.Type.MOVING if randf() < 0.35 else PlatformScript.Type.NORMAL
		_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), safe_type, plat_scale)
		
		# 2. Spawn Thorn hazard obstacle on opposite flank leaving wide breathing room
		var thorn_x: float
		if spawn_x < center:
			thorn_x = randf_range(center + 65.0, max_x)
		else:
			thorn_x = randf_range(min_x, center - 65.0)
			
		if absf(thorn_x - spawn_x) < 140.0:
			thorn_x = (center + 120.0) if spawn_x < center else (center - 120.0)
			
		_spawn_platform_at(Vector2(thorn_x, highest_spawned_y), PlatformScript.Type.THORN, plat_scale)
		last_x = spawn_x
	else:
		_spawn_platform_at(Vector2(spawn_x, highest_spawned_y), chosen_type, plat_scale)
		last_x = spawn_x
		
	# --- Floating Spike Ball Hazard Spawn (Active from 300 onwards) ---
	if GameState.score >= 300 and chosen_type != PlatformScript.Type.THORN and spike_ball_scene:
		platforms_since_last_spike += 1
		var diff_after_300 = clampf(float(GameState.score - 300) / 1000.0, 0.0, 1.0)
		var spike_chance = 0.18 + (diff_after_300 * 0.12) # 18% -> 30%
		if randf() < spike_chance and platforms_since_last_spike >= 3:
			var ball_pos = _calculate_safe_hazard_position(last_x, spawn_x, highest_spawned_y, gap, screen_w, min_x, max_x)
			if ball_pos != Vector2.ZERO:
				_spawn_spike_ball_at(ball_pos)
				platforms_since_last_spike = 0

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
		
	# Progressive difficulty: balanced and forgiving
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	var r = randf()
	var moving_chance = 0.18 + (diff * 0.06) # 18% -> 24%
	var crumble_chance = 0.10 + (diff * 0.04) # 10% -> 14%
	var spring_chance = 0.18 # 18% (more super bounces!)
	var thorn_chance = (0.05 + (diff * 0.03)) if GameState.score >= 300 else 0.02 # Slightly increased from 300 onwards
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

func _is_position_above_any_platform(cand_x: float, cand_y: float) -> bool:
	for plat in active_platforms:
		if not is_instance_valid(plat) or plat.is_broken:
			continue
		var plat_x = plat.global_position.x
		var plat_y = plat.global_position.y
		
		# If platform is beneath candidate or level with it (within 280px downward):
		if cand_y <= plat_y + 40.0 and cand_y >= plat_y - 280.0:
			if plat.platform_type == PlatformScript.Type.MOVING:
				# Moving platform sweeps back and forth: protect its entire corridor
				if cand_x >= plat.left_limit - 50.0 and cand_x <= plat.right_limit + 50.0:
					return true
			else:
				var half_w = 44.0 * absf(plat.scale.x)
				# 85px clearance ensures zero overlap with platform's vertical column
				if absf(cand_x - plat_x) < half_w + 45.0:
					return true
	return false

func _calculate_safe_hazard_position(from_x: float, to_x: float, top_y: float, gap: float, screen_w: float, min_x: float, max_x: float) -> Vector2:
	var center = screen_w / 2.0
	var playfield_left = center - 270.0
	var playfield_right = center + 270.0
	
	# Determine horizontal jump direction:
	var jumping_right = to_x > from_x + 35.0
	var jumping_left = to_x < from_x - 35.0
	
	# Natural jump corridor to protect completely:
	var corridor_min = minf(from_x, to_x) - 55.0
	var corridor_max = maxf(from_x, to_x) + 55.0
	
	# Build priority candidate positions
	var candidates: Array[Vector2] = []
	var ball_y = top_y + (gap * 0.45)
	
	if jumping_right:
		# 1. Outer right overshoot flank (past to_x towards the right wall)
		var right_flank_x = clampf(to_x + randf_range(95.0, 125.0), to_x + 90.0, playfield_right - 35.0)
		candidates.append(Vector2(right_flank_x, ball_y))
		
		# 2. Far left wall margin (behind takeoff)
		var left_margin_x = playfield_left + randf_range(30.0, 48.0)
		candidates.append(Vector2(left_margin_x, ball_y))
		
		# 3. Outer right wall margin
		var right_margin_x = playfield_right - randf_range(30.0, 48.0)
		candidates.append(Vector2(right_margin_x, ball_y))
	elif jumping_left:
		# 1. Outer left overshoot flank (past to_x towards the left wall)
		var left_flank_x = clampf(to_x - randf_range(95.0, 125.0), playfield_left + 35.0, to_x - 90.0)
		candidates.append(Vector2(left_flank_x, ball_y))
		
		# 2. Far right wall margin (behind takeoff)
		var right_margin_x = playfield_right - randf_range(30.0, 48.0)
		candidates.append(Vector2(right_margin_x, ball_y))
		
		# 3. Outer left wall margin
		var left_margin_x = playfield_left + randf_range(30.0, 48.0)
		candidates.append(Vector2(left_margin_x, ball_y))
	else:
		# Vertical corridor jump
		if to_x < center:
			candidates.append(Vector2(playfield_right - 40.0, ball_y))
			candidates.append(Vector2(randf_range(center + 85.0, max_x), ball_y))
		else:
			candidates.append(Vector2(playfield_left + 40.0, ball_y))
			candidates.append(Vector2(randf_range(min_x, center - 85.0), ball_y))
			
	# Test candidates: MUST NOT be above any platform AND MUST NOT be in natural corridor
	for cand in candidates:
		if cand.x >= corridor_min and cand.x <= corridor_max:
			continue
		if absf(cand.x - to_x) < 85.0 or absf(cand.x - from_x) < 85.0:
			continue
		if _is_position_above_any_platform(cand.x, cand.y):
			continue
		return cand
		
	return Vector2.ZERO

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
