extends StaticBody2D
class_name Platform

enum Type {
	NORMAL,
	MOVING,
	CRUMBLE,
	RAINBOW,
	THORN,
	MEME
}

@export var platform_type: Type = Type.NORMAL

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var landing_area: Area2D = $LandingArea
@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var spikes: Node2D = $Visuals/Spikes

# Moving platform variables
var move_speed: float = 135.0
var move_direction: float = 1.0
var left_limit: float = 75.0
var right_limit: float = 405.0

# Crumble state
var is_broken: bool = false
var default_texture: Texture2D
var thorn_texture: Texture2D
var spring_texture: Texture2D
var crumble_broken_texture: Texture2D

func _ready() -> void:
	if sprite:
		default_texture = sprite.texture
	if ResourceLoader.exists("res://assets/sprites/red_spike_platform.png"):
		thorn_texture = load("res://assets/sprites/red_spike_platform.png")
	elif ResourceLoader.exists("res://assets/sprites/red_spike_platform.svg"):
		thorn_texture = load("res://assets/sprites/red_spike_platform.svg")
	if ResourceLoader.exists("res://assets/sprites/spring_platforms.png"):
		spring_texture = load("res://assets/sprites/spring_platforms.png")
	if ResourceLoader.exists("res://assets/sprites/crumble_broken.png"):
		crumble_broken_texture = load("res://assets/sprites/crumble_broken.png")
	apply_type_style()
	var center = get_viewport_rect().size.x / 2.0
	left_limit = center - 270.0 + 85.0
	right_limit = center + 270.0 - 85.0
	# Randomize moving platform speed scaled progressively with score (gentle, easy to land on)
	var diff = clampf(float(GameState.score) / 1000.0, 0.0, 1.0)
	move_speed = randf_range(95.0 + (diff * 25.0), 140.0 + (diff * 35.0))
	if randf() > 0.5:
		move_direction = -1.0
		
	if landing_area:
		landing_area.body_entered.connect(_on_landing_area_body_entered)

func _physics_process(delta: float) -> void:
	if platform_type == Type.MOVING and not is_broken:
		position.x += move_direction * move_speed * delta
		if position.x <= left_limit:
			position.x = left_limit
			move_direction = 1.0
		elif position.x >= right_limit:
			position.x = right_limit
			move_direction = -1.0
			
	# Generous landing detection for edges and non-level side contacts
	_check_landing_area()

func apply_type_style() -> void:
	if not sprite:
		return
		
	if platform_type == Type.THORN and thorn_texture:
		sprite.texture = thorn_texture
		sprite.scale = Vector2(0.25, 0.25)
		sprite.modulate = Color.WHITE
		if spikes:
			spikes.visible = false
		return
	elif platform_type == Type.RAINBOW and spring_texture:
		sprite.texture = spring_texture
		sprite.scale = Vector2(0.50, 0.50)
		sprite.modulate = Color.WHITE
		if spikes:
			spikes.visible = false
		return
	elif platform_type == Type.CRUMBLE and crumble_broken_texture:
		sprite.texture = crumble_broken_texture
		sprite.scale = Vector2(0.55, 0.55)
		sprite.modulate = Color("d6d3d1") # Frosted fractured slate (zero human skin tones)
		if spikes:
			spikes.visible = false
		return
	elif default_texture:
		sprite.texture = default_texture
		sprite.scale = Vector2(0.185, 0.22)

	# Toggle fallback polygon spikes for THORN if no texture
	if spikes:
		spikes.visible = (platform_type == Type.THORN)
		
	# Tint platform sprite based on type
	match platform_type:
		Type.NORMAL:
			sprite.modulate = Color("f8fafc") # White / platinum
		Type.MOVING:
			sprite.modulate = Color("34d399") # Emerald green
		Type.CRUMBLE:
			sprite.modulate = Color("d6d3d1") # Cracked stone gray
		Type.RAINBOW:
			sprite.modulate = Color("818cf8") # Lavender crystal
		Type.THORN:
			sprite.modulate = Color("f43f5e") # Crimson hazard red
		Type.MEME:
			sprite.modulate = Color("fbbf24") # Golden amber

func _on_landing_area_body_entered(body: Node2D) -> void:
	_try_trigger_landing(body)

func _check_landing_area() -> void:
	if not landing_area or is_broken:
		return
	for body in landing_area.get_overlapping_bodies():
		_try_trigger_landing(body)

func _try_trigger_landing(body: Node2D) -> void:
	if is_broken:
		return
	if body is Robot or body.name == "Robot" or body.has_method("bounce"):
		var robot = body
		if robot.get("is_dead") == true or robot.get("is_falling_death") == true:
			return
			
		# Thorn hazard check: keep hazard bounding fair to visual spikes
		if platform_type == Type.THORN:
			var plat_hw = 44.0 * absf(scale.x)
			if absf(robot.global_position.x - global_position.x) > plat_hw + 8.0:
				return
				
		# Only bounce if falling or at jump apex (not rocketing upward through platforms)
		if robot.velocity.y >= -60.0:
			# Gently elevate robot if slightly below platform top for crisp, responsive jump feel
			var top_y = global_position.y - 28.0
			if robot.global_position.y > top_y:
				robot.global_position.y = top_y
			on_robot_landed(robot)

func on_robot_landed(robot: CharacterBody2D) -> void:
	if is_broken:
		return
		
	match platform_type:
		Type.NORMAL:
			robot.bounce(1.0)
			
		Type.MOVING:
			robot.bounce(1.0)
			
		Type.RAINBOW:
			# 1.5x Super bounce + MJ Hee-Hee sound + 360 flip + confetti + spring camera shake!
			robot.bounce(1.5)
			GameState.play_rainbow()
			GameState.trigger_effect(&"confetti", global_position)
			GameState.trigger_effect(&"flip")
			GameState.trigger_effect(&"spring_shake")
			
		Type.THORN:
			# Thorn platform kills immediately!
			GameState.trigger_effect(&"shatter", global_position)
			GameState.trigger_effect(&"screen_flash", Color(1.0, 0.15, 0.15, 0.6))
			GameState.trigger_effect(&"shake", 16.0)
			if robot.has_method("die"):
				robot.die()
			else:
				GameState.end_game()
				
		Type.CRUMBLE:
			robot.bounce(1.0)
			GameState.trigger_effect(&"shake", 4.0)
			# Breaks after 0.15s
			is_broken = true
			_trigger_crumble()
			
		Type.MEME:
			robot.bounce(1.0)
			GameState.trigger_meme()
			GameState.trigger_effect(&"pixel_emoji", global_position)

func _trigger_crumble() -> void:
	GameState.trigger_effect(&"shatter", global_position)
	if crumble_broken_texture and sprite:
		sprite.texture = crumble_broken_texture
		sprite.scale = Vector2(0.55, 0.55)
	var tween = create_tween()
	# Shake then fall
	tween.tween_property(visuals, "position:x", 6.0, 0.04)
	tween.tween_property(visuals, "position:x", -6.0, 0.04)
	tween.tween_property(visuals, "position:x", 0.0, 0.04)
	tween.tween_callback(func():
		collision_shape.set_deferred("disabled", true)
		if landing_area:
			landing_area.set_deferred("monitoring", false)
	)
	# Fade out & drop
	tween.tween_property(visuals, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(visuals, "position:y", 40.0, 0.2)
