extends Control
class_name BiomeBackground

## Dynamic Biome Ascent for Hopy
## Transforms the background across 5 distinct vertical altitude biomes:
## Biome 0 (0-249): Subterranean Reactor Core (Dark industrial conduits & rising energy motes)
## Biome 1 (250-499): Neon Skyline Rooftops (Skyscrapers & glowing window grids in parallax)
## Biome 2 (500-749): Emerald Aurora Stratosphere (Undulating aurora borealis ribbons & cirrus clouds)
## Biome 3 (750-999): Twilight Orbit Exosphere (Curved Earth horizon rim & orbital satellites)
## Biome 4 (1000+): Deep Void Supernova (Radiant cosmic nebula clouds & shooting stars)

@export var camera: Camera2D
@export var border_left: ColorRect
@export var border_right: ColorRect
@export var star_particles: CPUParticles2D

var current_biome: int = 0
var target_biome: int = 0
var transition_progress: float = 1.0 # 1.0 = fully transitioned
const TRANSITION_SPEED: float = 0.6 # ~1.6s smooth cross-fade

var anim_time: float = 0.0
var parallax_offset_y: float = 0.0

# Pre-computed skyline data for deterministic, non-flickering city generation
var skyline_buildings: Array = []
var satellite_pos_x: float = -60.0
var shooting_star_timer: float = 0.0
var shooting_star_active: bool = false
var shooting_star_start: Vector2 = Vector2.ZERO
var shooting_star_progress: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_skyline_data()
	GameState.color_scheme_changed.connect(_on_color_scheme_changed)
	_on_color_scheme_changed(GameState.color_scheme_index)

func _init_skyline_data() -> void:
	skyline_buildings.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 # Deterministic seed for aesthetic skyline
	var cur_x = 10.0
	while cur_x < 530.0:
		var b_w = rng.randf_range(48.0, 82.0)
		var b_h = rng.randf_range(160.0, 360.0)
		var has_antenna = rng.randf() > 0.4
		var windows = []
		var cols = int(b_w / 14.0)
		var rows = int(b_h / 22.0)
		for r in range(rows):
			for c in range(cols):
				if rng.randf() > 0.55:
					windows.append(Vector2(c * 14.0 + 8.0, r * 22.0 + 12.0))
		skyline_buildings.append({
			"x": cur_x,
			"w": b_w,
			"h": b_h,
			"has_antenna": has_antenna,
			"windows": windows
		})
		cur_x += b_w + rng.randf_range(6.0, 16.0)

func _on_color_scheme_changed(new_index: int) -> void:
	var biome_idx = clampi(new_index, 0, 4)
	if biome_idx != target_biome:
		current_biome = target_biome
		target_biome = biome_idx
		transition_progress = 0.0
		_update_borders_and_particles(target_biome)

func _update_borders_and_particles(biome_idx: int) -> void:
	if biome_idx >= GameState.COLOR_SCHEMES.size():
		return
	var scheme = GameState.COLOR_SCHEMES[biome_idx]
	var accent = scheme["accent1"]
	
	# Smoothly tween border colors to match biome theme
	var tween = create_tween().set_parallel(true)
	if border_left:
		tween.tween_property(border_left, "color", Color(accent.r, accent.g, accent.b, 0.45), 1.2)
	if border_right:
		tween.tween_property(border_right, "color", Color(accent.r, accent.g, accent.b, 0.45), 1.2)
		
	# Adaptive tuning of ambient particles per biome
	if star_particles:
		match biome_idx:
			0: # Reactor: rising ember motes
				star_particles.direction = Vector2(0, -1)
				star_particles.color = Color("818cf8")
				star_particles.color.a = 0.24
				star_particles.gravity = Vector2(0, -20)
			1: # Skyline: cool city night mist
				star_particles.direction = Vector2(0.4, 0.8)
				star_particles.color = Color("2dd4bf")
				star_particles.color.a = 0.22
				star_particles.gravity = Vector2(5, 15)
			2: # Stratosphere: emerald aurora dust
				star_particles.direction = Vector2(0.2, 1.0)
				star_particles.color = Color("6ee7b7")
				star_particles.color.a = 0.32
				star_particles.gravity = Vector2(0, 10)
			3: # Exosphere: purple vacuum drift
				star_particles.direction = Vector2(-0.2, 0.8)
				star_particles.color = Color("f472b6")
				star_particles.color.a = 0.28
				star_particles.gravity = Vector2(0, 20)
			4: # Supernova: cosmic starlight warp
				star_particles.direction = Vector2(0, 1.0)
				star_particles.color = Color("c084fc")
				star_particles.color.a = 0.45
				star_particles.gravity = Vector2(0, 35)

func _process(delta: float) -> void:
	anim_time += delta
	if transition_progress < 1.0:
		transition_progress = minf(1.0, transition_progress + delta * TRANSITION_SPEED)
		
	# Camera parallax computation
	if camera and is_instance_valid(camera):
		parallax_offset_y = camera.global_position.y * 0.08
		
	# Satellite drift in exosphere
	if target_biome == 3 or current_biome == 3:
		satellite_pos_x += delta * 18.0
		if satellite_pos_x > 600.0:
			satellite_pos_x = -60.0
			
	# Shooting star in supernova
	if target_biome == 4 or current_biome == 4:
		shooting_star_timer += delta
		if not shooting_star_active and shooting_star_timer > 3.5:
			shooting_star_timer = 0.0
			shooting_star_active = true
			shooting_star_progress = 0.0
			shooting_star_start = Vector2(randf_range(40.0, 380.0), randf_range(60.0, 280.0))
		if shooting_star_active:
			shooting_star_progress += delta * 2.2
			if shooting_star_progress >= 1.0:
				shooting_star_active = false
				
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0.0 or h <= 0.0:
		w = 540.0
		h = 960.0
		
	# Draw active biomes with cross-fade interpolation
	if transition_progress < 1.0 and current_biome != target_biome:
		var from_alpha = (1.0 - transition_progress)
		var to_alpha = transition_progress
		_draw_biome(current_biome, w, h, from_alpha)
		_draw_biome(target_biome, w, h, to_alpha)
	else:
		_draw_biome(target_biome, w, h, 1.0)

func _draw_biome(biome_idx: int, w: float, h: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	match biome_idx:
		0:
			_draw_subterranean_reactor(w, h, alpha)
		1:
			_draw_neon_skyline(w, h, alpha)
		2:
			_draw_emerald_stratosphere(w, h, alpha)
		3:
			_draw_twilight_exosphere(w, h, alpha)
		4:
			_draw_deep_void_supernova(w, h, alpha)

## Biome 0: Subterranean Reactor Core (Dark obsidian conduits & pulsing energy)
func _draw_subterranean_reactor(w: float, h: float, alpha: float) -> void:
	# Subtle bottom core glow
	var pulse = 0.10 + sin(anim_time * 2.0) * 0.04
	var core_color = Color(0.39, 0.40, 0.95, pulse * alpha) # Indigo craft
	var core_rect = Rect2(30.0, h - 180.0, w - 60.0, 180.0)
	draw_rect(core_rect, core_color, false, 2.0)
	
	# Edge reactor conduits
	var conduit_col = Color(0.25, 0.28, 0.42, 0.28 * alpha)
	var conduit_glow = Color(0.39, 0.40, 0.95, 0.45 * alpha)
	# Left conduit line
	draw_line(Vector2(20.0, 0.0), Vector2(20.0, h), conduit_col, 2.0)
	draw_line(Vector2(26.0, 0.0), Vector2(26.0, h), conduit_col, 1.0)
	# Right conduit line
	draw_line(Vector2(w - 20.0, 0.0), Vector2(w - 20.0, h), conduit_col, 2.0)
	draw_line(Vector2(w - 26.0, 0.0), Vector2(w - 26.0, h), conduit_col, 1.0)
	
	# Periodic energy junction notches
	var spacing = 120.0
	var offset = fmod(anim_time * 30.0, spacing)
	var y = offset
	while y < h:
		draw_line(Vector2(14.0, y), Vector2(26.0, y), conduit_glow, 2.0)
		draw_line(Vector2(w - 26.0, y), Vector2(w - 14.0, y), conduit_glow, 2.0)
		y += spacing

## Biome 1: Neon Skyline Rooftops (Dark cityscape & glowing window grids in parallax)
func _draw_neon_skyline(w: float, h: float, alpha: float) -> void:
	# City skyline at bottom, parallaxed gently
	var base_y = h - 60.0 - fmod(parallax_offset_y, 40.0)
	var b_col = Color(0.05, 0.07, 0.12, 0.65 * alpha) # Dark midnight navy
	var win_cyan = Color(0.18, 0.83, 0.75, 0.38 * alpha) # Teal window
	var win_lavender = Color(0.51, 0.55, 0.97, 0.32 * alpha) # Lavender window
	var antenna_col = Color(0.18, 0.83, 0.75, 0.55 * alpha)
	
	for b in skyline_buildings:
		var bx = b["x"]
		var bw = b["w"]
		var bh = b["h"]
		var by = base_y - bh
		var rect = Rect2(bx, by, bw, bh + 100.0)
		draw_rect(rect, b_col, true)
		draw_rect(rect, Color(0.15, 0.20, 0.32, 0.35 * alpha), false, 1.0)
		
		# Antenna spire
		if b["has_antenna"]:
			var ant_x = bx + bw / 2.0
			draw_line(Vector2(ant_x, by), Vector2(ant_x, by - 28.0), antenna_col, 1.5)
			# Pulsing red/cyan beacon dot
			var b_alpha = (0.5 + sin(anim_time * 4.0 + bx) * 0.5) * alpha
			draw_circle(Vector2(ant_x, by - 28.0), 2.5, Color(1.0, 0.25, 0.35, b_alpha))
			
		# Window dots
		for win_pos in b["windows"]:
			var wx = bx + win_pos.x
			var wy = by + win_pos.y
			if wy < base_y:
				var col = win_cyan if int(win_pos.x + win_pos.y) % 2 == 0 else win_lavender
				draw_rect(Rect2(wx, wy, 4.0, 6.0), col, true)

## Biome 2: Emerald Aurora Stratosphere (Undulating light ribbons & high cirrus clouds)
func _draw_emerald_stratosphere(w: float, h: float, alpha: float) -> void:
	# Undulating emerald & mint aurora ribbons across upper sky
	var wave_y_base = 220.0
	var segments = 24
	var step = w / float(segments)
	
	var pts_top: PackedVector2Array = []
	var pts_bottom: PackedVector2Array = []
	
	for i in range(segments + 1):
		var x = float(i) * step
		var wave1 = sin(x * 0.014 + anim_time * 1.2) * 28.0
		var wave2 = cos(x * 0.022 - anim_time * 0.9) * 16.0
		var y1 = wave_y_base + wave1 + wave2
		var y2 = y1 + 75.0 + sin(x * 0.01 + anim_time * 0.5) * 20.0
		pts_top.append(Vector2(x, y1))
		pts_bottom.append(Vector2(x, y2))
		
	# Draw glowing emerald aurora ribbon
	var poly: PackedVector2Array = []
	for p in pts_top:
		poly.append(p)
	for i in range(pts_bottom.size() - 1, -1, -1):
		poly.append(pts_bottom[i])
		
	var aurora_col = Color(0.06, 0.73, 0.51, 0.16 * alpha) # Emerald jade
	var aurora_glow = Color(0.43, 0.91, 0.72, 0.28 * alpha) # Mint glow line
	draw_colored_polygon(poly, aurora_col)
	draw_polyline(pts_top, aurora_glow, 2.0)
	
	# Wispy high-altitude cloud bands
	var cloud_col = Color(0.12, 0.35, 0.28, 0.14 * alpha)
	var cy1 = 440.0 + sin(anim_time * 0.4) * 12.0
	draw_line(Vector2(30.0, cy1), Vector2(w - 60.0, cy1), cloud_col, 18.0)
	var cy2 = 620.0 + cos(anim_time * 0.3) * 15.0
	draw_line(Vector2(80.0, cy2), Vector2(w - 40.0, cy2), cloud_col, 24.0)

## Biome 3: Twilight Orbit Exosphere (Curved Earth horizon & orbital satellite)
func _draw_twilight_exosphere(w: float, h: float, alpha: float) -> void:
	# Curved Earth limb at bottom
	var center_arc = Vector2(w / 2.0, h + 280.0)
	var radius = 420.0
	var arc_pts: PackedVector2Array = []
	var arc_glow_pts: PackedVector2Array = []
	var arc_steps = 30
	for i in range(arc_steps + 1):
		var angle = PI + 0.5 + (float(i) / float(arc_steps)) * (PI - 1.0)
		var pt = center_arc + Vector2(cos(angle), sin(angle)) * radius
		arc_pts.append(pt)
		arc_glow_pts.append(center_arc + Vector2(cos(angle), sin(angle)) * (radius + 14.0))
		
	var planet_col = Color(0.08, 0.06, 0.18, 0.75 * alpha) # Deep shadow planet
	var limb_col = Color(0.66, 0.33, 0.97, 0.35 * alpha) # Amethyst atmospheric glow
	var outer_glow = Color(0.96, 0.45, 0.71, 0.18 * alpha) # Champagne haze
	
	draw_polyline(arc_glow_pts, outer_glow, 16.0)
	draw_polyline(arc_pts, limb_col, 4.0)
	
	# Orbiting satellite silhouette
	var sat_y = 160.0 + sin(anim_time * 0.8) * 14.0
	var sat_x = satellite_pos_x
	if sat_x > -40.0 and sat_x < w + 40.0:
		var sat_col = Color(0.85, 0.88, 0.95, 0.65 * alpha)
		var solar_col = Color(0.51, 0.55, 0.97, 0.55 * alpha)
		# Satellite body
		draw_rect(Rect2(sat_x - 8.0, sat_y - 6.0, 16.0, 12.0), sat_col, true)
		# Solar panel wings
		draw_rect(Rect2(sat_x - 26.0, sat_y - 4.0, 15.0, 8.0), solar_col, true)
		draw_rect(Rect2(sat_x + 11.0, sat_y - 4.0, 15.0, 8.0), solar_col, true)
		# Blink beacon
		var beacon_a = (0.5 + sin(anim_time * 5.0) * 0.5) * alpha
		draw_circle(Vector2(sat_x, sat_y - 8.0), 2.0, Color(1.0, 0.3, 0.4, beacon_a))

## Biome 4: Deep Void Supernova (Nebula clouds, star clusters & shooting stars)
func _draw_deep_void_supernova(w: float, h: float, alpha: float) -> void:
	# Soft breathing nebula clouds
	var breath1 = 1.0 + sin(anim_time * 0.9) * 0.08
	var neb1_col = Color(0.75, 0.52, 0.99, 0.12 * alpha) # Starlight violet
	draw_circle(Vector2(w * 0.35, h * 0.28), 110.0 * breath1, neb1_col)
	
	var breath2 = 1.0 + cos(anim_time * 0.7) * 0.08
	var neb2_col = Color(0.22, 0.74, 0.97, 0.10 * alpha) # Azure cyan
	draw_circle(Vector2(w * 0.72, h * 0.55), 130.0 * breath2, neb2_col)
	
	# Shooting star streak
	if shooting_star_active:
		var dir = Vector2(1.2, 0.9).normalized()
		var p1 = shooting_star_start + dir * (shooting_star_progress * 220.0)
		var p2 = p1 - dir * 45.0
		var star_a = (1.0 - absf(shooting_star_progress - 0.5) * 2.0) * alpha
		var streak_col = Color(1.0, 1.0, 1.0, star_a)
		draw_line(p2, p1, streak_col, 2.0)
		draw_circle(p1, 2.5, Color(0.75, 0.85, 1.0, star_a))
