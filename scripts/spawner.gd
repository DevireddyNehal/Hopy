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
	
	# Determine if this platform step will spawn a floating circle spike ball
	var will_spawn_spike: bool = false
	if GameState.score >= 200 and chosen_type != PlatformScript.Type.THORN and spike_ball_scene:
		if platforms_since_last_spike >= 2:
			var spike_chance: float
			if GameState.score >= 500:
				var diff_after_500 = clampf(float(GameState.score - 500) / 1000.0, 0.0, 1.0)
				spike_chance = 0.42 + (diff_after_500 * 0.15) # 42% -> 57%
			else:
				var diff_after_200 = clampf(float(GameState.score - 200) / 300.0, 0.0, 1.0)
				spike_chance = 0.30 + (diff_after_200 * 0.12) # 30% -> 42%
			if randf() < spike_chance:
				will_spawn_spike = true
	
	# Gap pacing based on platform type (forgiving close gaps):
	# When spawning a floating circle spike, provide extra headroom (160 - 175px)
	# so the spike sits high up in the middle with ample space below to maneuver.
	var gap = randf_range(MIN_GAP_Y, MAX_GAP_Y)
	if chosen_type == PlatformScript.Type.CRUMBLE:
		gap = randf_range(90.0, 120.0) # Gentle rapid hops for crumbles
	elif chosen_type == PlatformScript.Type.RAINBOW:
		gap = randf_range(115.0, 140.0)
	elif will_spawn_spike:
		gap = randf_range(160.0, 175.0)
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
		var safe_plat = _spawn_platform_at(Vector2(spawn_x, highest_spawned_y), safe_type, plat_scale)
		if safe_type == PlatformScript.Type.NORMAL and platform_count > 4:
			if randf() < _get_erratic_platform_chance():
				safe_plat.is_erratic = true
		
		# 2. Spawn Thorn hazard obstacle on opposite flank leaving wide breathing room
		var thorn_x: float
		if spawn_x < center:
			thorn_x = randf_range(center + 65.0, max_x)
		else:
			thorn_x = randf_range(min_x, center - 65.0)
			
		if absf(thorn_x - spawn_x) < 140.0:
			thorn_x = (center + 120.0) if spawn_x < center else (center - 120.0)
			
		var thorn_plat = _spawn_platform_at(Vector2(thorn_x, highest_spawned_y), PlatformScript.Type.THORN, plat_scale)
		# Movable spikes past 500 score: 45% patrol horizontally!
		if GameState.score >= 500 and randf() < 0.45:
			thorn_plat.is_moving_thorn = true
			thorn_plat.move_speed = randf_range(80.0, 130.0)
		last_x = spawn_x
	else:
		var plat = _spawn_platform_at(Vector2(spawn_x, highest_spawned_y), chosen_type, plat_scale)
		# Erratic normal platforms: look solid then suddenly juke away when approached
		if chosen_type == PlatformScript.Type.NORMAL and platform_count > 4:
			if randf() < _get_erratic_platform_chance():
				plat.is_erratic = true
		last_x = spawn_x
		
	# --- Floating Spike Ball Hazard Spawn (Active from 200 onwards) ---
	if will_spawn_spike:
		var ball_pos = _calculate_safe_hazard_position(last_x, spawn_x, highest_spawned_y, gap, screen_w, min_x, max_x)
		if ball_pos != Vector2.ZERO:
			var sb = _spawn_spike_ball_at(ball_pos)
			# Movable floating spikes past 500 score: 40% patrol horizontally!
			if GameState.score >= 500 and randf() < 0.40:
				sb.horizontal_speed = randf_range(45.0, 75.0)
				sb.horizontal_range = randf_range(40.0, 75.0)
			platforms_since_last_spike = 0
		else:
			platforms_since_last_spike += 1
	elif GameState.score >= 200:
		platforms_since_last_spike += 1

## Cyclic wave pacing for erratic "fake-normal" platforms that look solid then suddenly juke away.
## Oscillates endlessly between "Really Common" (~44% chance) and "Uncommon" (~7% chance) in waves.
func _get_erratic_platform_chance() -> float:
	var wave = sin(float(GameState.score) * 0.024)
	if wave >= 0.0:
		return 0.44 # Hot wave: really common
	else:
		return 0.07 # Cold wave: uncommon

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
	var moving_chance = 0.18 + (diff * 0.04) # 18% -> 22%
	var crumble_chance = 0.10 + (diff * 0.03) # 10% -> 13%
	var spring_chance = 0.16 # 16% (super bounces)
	
	# Spiked platform frequency:
	# - Under 300: 2%
	# - 300 to 499: 6% - 8%
	# - 500+ score: significantly increased to 18% - 25% for high-stakes climbing
	var thorn_chance: float
	if GameState.score >= 500:
		thorn_chance = 0.18 + (diff * 0.07) # 18% -> 25% past 500 score
	elif GameState.score >= 300:
		thorn_chance = 0.06 + (diff * 0.02) # 6% -> 8%
	else:
		thorn_chance = 0.02 # 2%
		
	var meme_chance = 0.05 # 5%
	
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
				# 70px clearance ensures zero overlap with platform's vertical column
				if absf(cand_x - plat_x) < half_w + 25.0:
					return true
	return false

func _calculate_safe_hazard_position(from_x: float, to_x: float, top_y: float, gap: float, screen_w: float, min_x: float, max_x: float) -> Vector2:
	var center = screen_w / 2.0
	var playfield_left = center - 270.0
	var playfield_right = center + 270.0
	
	# Place the spike high up in the gap, leaving generous headroom underneath to jump & maneuver
	var ball_y = top_y + (gap * 0.28)
	
	# Build prioritized candidates:
	# Priority 1: High and in the middle between takeoff (from_x) and landing (to_x)
	var mid_x = (from_x + to_x) / 2.0
	var candidates: Array[Vector2] = []
	
	# 1. Exact middle between platforms
	candidates.append(Vector2(mid_x, ball_y))
	# 2. Slight offsets around the middle
	candidates.append(Vector2(mid_x + 25.0, ball_y))
	candidates.append(Vector2(mid_x - 25.0, ball_y))
	# 3. Center corridor of screen
	candidates.append(Vector2(center, ball_y))
	candidates.append(Vector2(center - 35.0, ball_y))
	candidates.append(Vector2(center + 35.0, ball_y))
	# 4. Flank fallbacks (in case the middle has another platform directly underneath)
	candidates.append(Vector2(to_x + 95.0, ball_y))
	candidates.append(Vector2(to_x - 95.0, ball_y))
	candidates.append(Vector2(from_x + 90.0, ball_y))
	candidates.append(Vector2(from_x - 90.0, ball_y))
	
	for cand in candidates:
		# Keep within screen playfield bounds
		if cand.x < playfield_left + 40.0 or cand.x > playfield_right - 40.0:
			continue
		# Must NOT be directly on top of the target (upper) platform
		if absf(cand.x - to_x) < 55.0:
			continue
		# Must NOT be directly on top of the takeoff (lower) platform
		if absf(cand.x - from_x) < 55.0:
			continue
		# Must NOT be directly on top of ANY platform below it
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
