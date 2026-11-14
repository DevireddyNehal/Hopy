extends Camera2D
class_name FollowCamera

@export var target: Node2D
@export var smooth_speed: float = 8.0

var highest_y: float = 0.0
var viewport_half_height: float = 324.0 # 648 / 2

func _ready() -> void:
	highest_y = global_position.y

func _physics_process(delta: float) -> void:
	if not target:
		return
		
	# 1. Camera ONLY moves upward (negative Y)
	# When target goes higher than current camera center, smoothly interpolate up
	if target.global_position.y < global_position.y:
		global_position.y = lerp(global_position.y, target.global_position.y, smooth_speed * delta)
		if global_position.y < highest_y:
			highest_y = global_position.y
			
	# 2. Falling below screen death condition:
	# If target drops below the visible bottom of the camera view:
	var half_h = get_viewport_rect().size.y / 2.0
	var screen_bottom = global_position.y + half_h + 60.0
	if target.global_position.y > screen_bottom:
		if target.has_method("die"):
			target.die()
		else:
			GameState.end_game()
