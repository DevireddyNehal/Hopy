class_name PlayerAdapter
extends RefCounted
## Integration interface between special platforms and the main player script.
##
## Platforms never touch the player's variables. They call the static functions
## below, which call methods on the player. If a method is missing, the call is
## skipped and a warning is printed once.
##
## PLAYER REQUIREMENTS
##   - CharacterBody2D, added to the group "player".
##   - Collision layer 1. Collision mask includes layer 2 (platforms).
##   - velocity.y is positive when falling (Godot's default, +y is down).
##
## PLAYER METHODS
##   - on_platform_landed(platform_type: int, landing_position: Vector2)
##   - apply_default_bounce()
##   - apply_boosted_bounce(velocity_y: float)
##   - apply_steering_modifier(multiplier: float, duration: float)

const PLAYER_GROUP: StringName = &"player"

static var _warned: Dictionary = {}


static func is_player(node: Node) -> bool:
	return node is CharacterBody2D and node.is_in_group(PLAYER_GROUP)


static func notify_landing(player: Node, platform_type: int, landing_position: Vector2) -> void:
	_call_if_present(player, &"on_platform_landed", [platform_type, landing_position], false)


static func apply_default_bounce(player: Node) -> void:
	_call_if_present(player, &"apply_default_bounce", [], true)


static func apply_boosted_bounce(player: Node, velocity_y: float) -> void:
	_call_if_present(player, &"apply_boosted_bounce", [velocity_y], true)


static func apply_steering_modifier(player: Node, multiplier: float, duration: float) -> void:
	_call_if_present(player, &"apply_steering_modifier", [multiplier, duration], true)


static func _call_if_present(target: Node, method_name: StringName, args: Array, warn_if_missing: bool) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method(method_name):
		target.callv(method_name, args)
		return
	if warn_if_missing and not _warned.has(method_name):
		_warned[method_name] = true
		push_warning("PlayerAdapter: player is missing method '%s'. The platform effect is skipped." % method_name)


## Helper for the player. A new request replaces the current one and restarts
## the timer, so repeated glitches never stack.
class SteeringModifier extends RefCounted:
	var multiplier: float = 1.0
	var _time_left: float = 0.0

	func request(new_multiplier: float, duration: float) -> void:
		if duration <= 0.0:
			clear()
			return
		multiplier = new_multiplier
		_time_left = duration

	func update(delta: float) -> void:
		if _time_left <= 0.0:
			return
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			multiplier = 1.0

	func is_active() -> bool:
		return _time_left > 0.0

	func clear() -> void:
		multiplier = 1.0
		_time_left = 0.0
