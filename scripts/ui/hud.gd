extends Control

signal pause_requested

var _score_label: Label
var _combo_label: Label
var _best_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	_score_label = _make_label("SCORE: 0")
	row.add_child(_score_label)
	_combo_label = _make_label("COMBO: 0")
	row.add_child(_combo_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_best_label = _make_label("BEST: 0")
	row.add_child(_best_label)

	var pause_button := Button.new()
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(pause_button)

	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.best_score_changed.connect(_on_best_score_changed)
	_on_score_changed(GameState.score)
	_on_combo_changed(GameState.combo)
	_on_best_score_changed(GameState.best_score)


func set_best_score(value: int) -> void:
	if is_instance_valid(_best_label):
		_on_best_score_changed(value)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label


func _on_score_changed(value: int) -> void:
	if is_instance_valid(_score_label):
		_score_label.text = "SCORE: %d" % value


func _on_combo_changed(value: int) -> void:
	if is_instance_valid(_combo_label):
		_combo_label.text = "COMBO: %d" % value


func _on_best_score_changed(value: int) -> void:
	if is_instance_valid(_best_label):
		_best_label.text = "BEST: %d" % value