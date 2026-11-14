extends Control

signal restart_requested
signal title_requested

var _score_label: Label
var _best_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400.0, 320.0)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "GAME OVER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	layout.add_child(heading)

	_score_label = _make_label("SCORE: 0")
	layout.add_child(_score_label)
	_best_label = _make_label("BEST: 0")
	layout.add_child(_best_label)

	var restart_button := Button.new()
	restart_button.text = "PLAY AGAIN"
	restart_button.custom_minimum_size = Vector2(0.0, 44.0)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	layout.add_child(restart_button)

	var title_button := Button.new()
	title_button.text = "TITLE"
	title_button.custom_minimum_size = Vector2(0.0, 44.0)
	title_button.pressed.connect(func() -> void: title_requested.emit())
	layout.add_child(title_button)


func set_results(score: int, best_score: int) -> void:
	if is_instance_valid(_score_label):
		_score_label.text = "SCORE: %d" % score
	if is_instance_valid(_best_label):
		_best_label.text = "BEST: %d" % best_score


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	return label