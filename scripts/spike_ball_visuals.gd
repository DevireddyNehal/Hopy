extends Node2D

func _draw() -> void:
	# 1. Subtle hazard glow circle behind spikes
	draw_circle(Vector2.ZERO, 27.0, Color(1.0, 0.1, 0.2, 0.18))
	
	# 2. Draw 8 sharp spikes
	var spike_count = 8
	var outer_len = 25.0
	var base_r = 13.5
	var base_spread = 0.28
	
	for i in range(spike_count):
		var angle = i * (TAU / spike_count)
		var p_tip = Vector2(cos(angle), sin(angle)) * outer_len
		var p_left = Vector2(cos(angle - base_spread), sin(angle - base_spread)) * base_r
		var p_right = Vector2(cos(angle + base_spread), sin(angle + base_spread)) * base_r
		
		var points = PackedVector2Array([p_left, p_tip, p_right])
		# Spike base (dark steel)
		draw_colored_polygon(points, Color(0.18, 0.18, 0.24))
		# Spike tip accent (crimson danger)
		var tip_accent = PackedVector2Array([
			p_left.lerp(p_tip, 0.45),
			p_tip,
			p_right.lerp(p_tip, 0.45)
		])
		draw_colored_polygon(tip_accent, Color(1.0, 0.15, 0.25))
	
	# 3. Central iron sphere
	draw_circle(Vector2.ZERO, 14.5, Color(0.12, 0.13, 0.18))
	# Rim highlight
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 32, Color(0.4, 0.45, 0.55), 1.5, true)
	
	# 4. Glowing menacing core
	draw_circle(Vector2.ZERO, 7.5, Color(1.0, 0.15, 0.25))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.7, 0.75))
	draw_circle(Vector2(-2, -2), 1.8, Color(1.0, 1.0, 1.0, 0.9))
