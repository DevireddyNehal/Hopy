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
@onready var base_rect: ColorRect = $Visuals/BaseRect
@onready var spikes: Node2D = $Visuals/Spikes

# Moving platform variables
var move_speed: float = 120.0
var move_direction: float = 1.0
var left_limit: float = 100.0
var right_limit: float = 1050.0

# Crumble state
var is_broken: bool = false

func _ready() -> void:
	apply_type_style()
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
	# Hide spikes by default
	if spikes:
		spikes.visible = (platform_type == Type.THORN)
	
	# Visual placeholder colors
	match platform_type:
		Type.NORMAL:
			base_rect.color = Color("00f0ff") # Electric Cyan
		Type.MOVING:
			base_rect.color = Color("39ff14") # Lime Green
		Type.CRUMBLE:
			base_rect.color = Color("ffaa00") # Crumbly Orange
		Type.RAINBOW:
			base_rect.color = Color("ff007f") # Hot Magenta
		Type.THORN:
			base_rect.color = Color("d50000") # Crimson Hazard Red
		Type.MEME:
			base_rect.color = Color("ffd600") # Gold / Meme Yellow

func on_robot_landed(robot: CharacterBody2D) -> void:
	if is_broken:
		return
		
	match platform_type:
		Type.NORMAL:
			robot.bounce(1.0)
			
		Type.MOVING:
			robot.bounce(1.0)
			
		Type.RAINBOW:
			# 1.5x Super bounce
			robot.bounce(1.5)
			
		Type.THORN:
			# Thorn platform kills immediately!
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

func _trigger_crumble() -> void:
	var tween = create_tween()
	# Shake then fall
	tween.tween_property(visuals, "position:x", 4.0, 0.04)
	tween.tween_property(visuals, "position:x", -4.0, 0.04)
	tween.tween_property(visuals, "position:x", 0.0, 0.04)
	tween.tween_callback(func():
		collision_shape.set_deferred("disabled", true)
	)
	# Fade out & drop
	tween.tween_property(visuals, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(visuals, "position:y", 30.0, 0.2)
