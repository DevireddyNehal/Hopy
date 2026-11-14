extends Control

signal start_requested

var _best_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 340.0)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "HOPY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.2, 0.92, 1.0))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Bounce higher. Don't fall."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	layout.add_child(subtitle)

	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.add_theme_font_size_override("font_size", 18)
	layout.add_child(_best_label)

	var controls := Label.new()
	controls.text = "Move: A/D or arrow keys\nPause: Esc"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(controls)

	var start_button := Button.new()
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(0.0, 48.0)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start_pressed)
	layout.add_child(start_button)


func set_best_score(value: int) -> void:
	if is_instance_valid(_best_label):
		_best_label.text = "BEST: %d" % value


func _on_start_pressed() -> void:
	start_requested.emit()