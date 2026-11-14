extends CanvasLayer
class_name HUD

@onready var score_label: Label = $Control/MarginContainer/TopBar/ScoreContainer/ScoreLabel
@onready var best_label: Label = $Control/MarginContainer/TopBar/BestContainer/BestLabel
@onready var combo_container: Control = $Control/ComboContainer
@onready var combo_label: Label = $Control/ComboContainer/ComboLabel

@onready var meme_card: PanelContainer = $Control/MemeCard
@onready var meme_label: Label = $Control/MemeCard/MarginContainer/MemeLabel
var meme_tween: Tween

@onready var milestone_banner: PanelContainer = %MilestoneBanner
@onready var milestone_label: Label = %MilestoneLabel
var milestone_tween: Tween

@onready var left_sidebar: Control = $Control/LeftMemeSideBar if has_node("Control/LeftMemeSideBar") else null
@onready var right_sidebar: Control = $Control/RightMemeSideBar if has_node("Control/RightMemeSideBar") else null
var _last_screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.best_score_changed.connect(_on_best_score_changed)
	GameState.meme_triggered.connect(_show_meme_card)
	GameState.milestone_reached.connect(_show_milestone)
	
	# Initial values
	_on_score_changed(GameState.score)
	_on_combo_changed(GameState.combo)
	_on_best_score_changed(GameState.best_score)
	if meme_card:
		meme_card.visible = false
	if milestone_banner:
		milestone_banner.visible = false
		
	get_tree().root.size_changed.connect(_update_sidebar_layout)
	_update_sidebar_layout.call_deferred()

func _process(_delta: float) -> void:
	var curr_size = get_viewport().get_visible_rect().size
	if curr_size != _last_screen_size:
		_last_screen_size = curr_size
		_update_sidebar_layout()

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = str(new_score)

func _on_best_score_changed(new_best: int) -> void:
	if best_label:
		best_label.text = "BEST: " + str(new_best)

func _on_combo_changed(new_combo: int) -> void:
	if not combo_container or not combo_label:
		return
		
	if new_combo > 1:
		combo_container.visible = true
		if new_combo >= 10:
			combo_label.text = "⚡ ×" + str(new_combo) + " HYPER COMBO! ⚡"
			combo_label.modulate = Color("ff007f")
		elif new_combo >= 5:
			combo_label.text = "★ ×" + str(new_combo) + " SUPER COMBO! ★"
			combo_label.modulate = Color("ffb300")
		else:
			combo_label.text = "×" + str(new_combo) + " COMBO!"
			combo_label.modulate = Color("00f0ff")
		
		# Punchy pop animation on increment
		var tween = create_tween()
		combo_label.pivot_offset = combo_label.size / 2.0
		combo_label.scale = Vector2(1.35, 1.35)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.14)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		combo_container.visible = false

func _show_meme_card(text: String) -> void:
	if not meme_card or not meme_label:
		return
	meme_label.text = "✨ " + text.to_upper() + " ✨"
	meme_card.visible = true
	meme_card.modulate.a = 1.0
	meme_card.scale = Vector2(0.2, 0.2)
	meme_card.pivot_offset = meme_card.size / 2.0
	
	if meme_tween and meme_tween.is_valid():
		meme_tween.kill()
		
	meme_tween = create_tween()
	meme_tween.tween_property(meme_card, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	meme_tween.tween_property(meme_card, "scale", Vector2(1.0, 1.0), 0.08)
	meme_tween.tween_interval(1.8)
	meme_tween.tween_property(meme_card, "modulate:a", 0.0, 0.25)
	meme_tween.tween_callback(func(): meme_card.visible = false)

func _show_milestone(points: int) -> void:
	if not milestone_banner or not milestone_label:
		return
	if points == 500:
		milestone_label.text = "🔥 500 PTS REACHED! 🔥"
	elif points == 1000:
		milestone_label.text = "👑 1000 PTS LEGEND! 👑"
	else:
		milestone_label.text = "★ " + str(points) + " PTS MILESTONE! ★"
		
	milestone_banner.visible = true
	milestone_banner.modulate.a = 1.0
	milestone_banner.scale = Vector2(0.4, 0.4)
	milestone_banner.pivot_offset = milestone_banner.size / 2.0
	
	if milestone_tween and milestone_tween.is_valid():
		milestone_tween.kill()
		
	milestone_tween = create_tween()
	milestone_tween.tween_property(milestone_banner, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	milestone_tween.tween_property(milestone_banner, "scale", Vector2(1.0, 1.0), 0.1)
	milestone_tween.tween_interval(2.0)
	milestone_tween.tween_property(milestone_banner, "modulate:a", 0.0, 0.3)
	milestone_tween.tween_callback(func(): milestone_banner.visible = false)

func _update_sidebar_layout() -> void:
	var vp_rect = get_viewport().get_visible_rect()
	var screen_w = vp_rect.size.x
	var screen_h = vp_rect.size.y
	var center_x = screen_w / 2.0
	
	# Central playfield spans [center_x - 270.0, center_x + 270.0]
	var playfield_left = center_x - 270.0
	var playfield_right = center_x + 270.0
	var pillar_width = playfield_left
	
	if pillar_width < 120.0:
		# If the screen is too narrow to have meaningful black margins,
		# hide sidebars so they NEVER obscure the 540px central gameplay tower!
		if left_sidebar:
			left_sidebar.visible = false
		if right_sidebar:
			right_sidebar.visible = false
		return
		
	# Screen has plenty of black pillarbox space (e.g. maximized on 1080p desktop)
	if left_sidebar:
		left_sidebar.visible = true
		left_sidebar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var left_w = left_sidebar.size.x
		var left_h = left_sidebar.size.y
		# Center horizontally inside [0, playfield_left]
		var target_x = (pillar_width - left_w) / 2.0
		# Clamp to stay firmly in black area and away from playfield edge
		target_x = clampf(target_x, 15.0, playfield_left - left_w - 20.0)
		var target_y = (screen_h - left_h) / 2.0
		left_sidebar.position = Vector2(target_x, target_y)
		
	if right_sidebar:
		right_sidebar.visible = true
		right_sidebar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var right_w = right_sidebar.size.x
		var right_h = right_sidebar.size.y
		# Center horizontally inside [playfield_right, screen_w]
		var right_center = playfield_right + (pillar_width / 2.0)
		var target_x = right_center - (right_w / 2.0)
		target_x = clampf(target_x, playfield_right + 20.0, screen_w - right_w - 15.0)
		var target_y = (screen_h - right_h) / 2.0
		right_sidebar.position = Vector2(target_x, target_y)
