extends Control

signal resume_requested
signal restart_requested
signal title_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 300.0)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "PAUSED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	layout.add_child(heading)

	var resume_button := _make_button("RESUME")
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	layout.add_child(resume_button)

	var restart_button := _make_button("RESTART")
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	layout.add_child(restart_button)

	var title_button := _make_button("TITLE")
	title_button.pressed.connect(func() -> void: title_requested.emit())
	layout.add_child(title_button)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	return button