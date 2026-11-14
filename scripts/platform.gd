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
@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var spikes: Node2D = $Visuals/Spikes

# Moving platform variables
var move_speed: float = 240.0
var move_direction: float = 1.0
var left_limit: float = 100.0
var right_limit: float = 1820.0

# Crumble state
var is_broken: bool = false

func _ready() -> void:
	apply_type_style()
	right_limit = get_viewport_rect().size.x - 100.0
	# Randomize moving platform start direction
	if randf() > 0.5:
		move_direction = -1.0

func _physics_process(delta: float) -> void:
	if platform_type == Type.MOVING and not is_broken:
		position.x += move_direction * move_speed * delta
		if position.x <= left_limit:
			position.x = left_limit
			move_direction = 1.0
		elif position.x >= right_limit:
			position.x = right_limit
			move_direction = -1.0

func apply_type_style() -> void:
	# Toggle spikes for THORN
	if spikes:
		spikes.visible = (platform_type == Type.THORN)
	
	if not sprite:
		return
		
	# Tint platform sprite based on type
	match platform_type:
		Type.NORMAL:
			sprite.modulate = Color(1.0, 1.0, 1.0)
		Type.MOVING:
			sprite.modulate = Color(0.3, 1.0, 0.45) # Toxic neon green
		Type.CRUMBLE:
			sprite.modulate = Color(1.0, 0.65, 0.2) # Crumble rust
		Type.RAINBOW:
			sprite.modulate = Color(1.0, 0.25, 0.9) # Hot magenta
		Type.THORN:
			sprite.modulate = Color(1.0, 0.2, 0.2) # Crimson hazard
		Type.MEME:
			sprite.modulate = Color(1.0, 0.88, 0.1) # Golden yellow

func on_robot_landed(robot: CharacterBody2D) -> void:
	if is_broken:
		return
		
	match platform_type:
		Type.NORMAL:
			robot.bounce(1.0)
			
		Type.MOVING:
			robot.bounce(1.0)
			
		Type.RAINBOW:
			# 1.5x Super bounce + MJ Hee-Hee sound + 360 flip + confetti!
			robot.bounce(1.5)
			GameState.play_rainbow()
			GameState.trigger_effect(&"confetti", global_position)
			GameState.trigger_effect(&"flip")
			
		Type.THORN:
			# Thorn platform kills immediately!
			GameState.trigger_effect(&"shatter", global_position)
			GameState.trigger_effect(&"screen_flash", Color(1.0, 0.15, 0.15, 0.6))
			if robot.has_method("die"):
				robot.die()
			else:
				GameState.end_game()
				
		Type.CRUMBLE:
			robot.bounce(1.0)
			# Breaks after 0.15s
			is_broken = true
			_trigger_crumble()
			
		Type.MEME:
			robot.bounce(1.0)
			GameState.trigger_meme()
			GameState.trigger_effect(&"pixel_emoji", global_position)

func _trigger_crumble() -> void:
	GameState.trigger_effect(&"shatter", global_position)
	var tween = create_tween()
	# Shake then fall
	tween.tween_property(visuals, "position:x", 6.0, 0.04)
	tween.tween_property(visuals, "position:x", -6.0, 0.04)
	tween.tween_property(visuals, "position:x", 0.0, 0.04)
	tween.tween_callback(func():
		collision_shape.set_deferred("disabled", true)
	)
	# Fade out & drop
	tween.tween_property(visuals, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(visuals, "position:y", 40.0, 0.2)
