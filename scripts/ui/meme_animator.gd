class_name MemeAnimator
extends Control

@export var sprite_sheet: Texture2D
@export var hframes: int = 31
@export var fps: float = 24.0
@export var frame_size: Vector2 = Vector2(160, 90)
@export var loop: bool = true

var _current_frame: int = 0
var _timer: float = 0.0
var _atlas: AtlasTexture

func _ready() -> void:
	custom_minimum_size = frame_size
	if sprite_sheet:
		_atlas = AtlasTexture.new()
		_atlas.atlas = sprite_sheet
		_update_frame(0)

func set_sheet(texture: Texture2D, count: int, rate: float, size_px: Vector2) -> void:
	sprite_sheet = texture
	hframes = count
	fps = rate
	frame_size = size_px
	custom_minimum_size = frame_size
	_atlas = AtlasTexture.new()
	_atlas.atlas = sprite_sheet
	_current_frame = 0
	_timer = 0.0
	_update_frame(0)

func _process(delta: float) -> void:
	if not sprite_sheet or hframes <= 1:
		return
	_timer += delta
	var frame_dur = 1.0 / fps
	while _timer >= frame_dur:
		_timer -= frame_dur
		_current_frame += 1
		if _current_frame >= hframes:
			if loop:
				_current_frame = 0
			else:
				_current_frame = hframes - 1
				break
		_update_frame(_current_frame)

func _update_frame(idx: int) -> void:
	if not _atlas:
		return
	_atlas.region = Rect2(idx * frame_size.x, 0, frame_size.x, frame_size.y)
	queue_redraw()

func _draw() -> void:
	if _atlas:
		var draw_pos = (size - frame_size) / 2.0
		draw_texture(_atlas, draw_pos)
