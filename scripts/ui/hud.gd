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

@onready var disclaimer_banner: PanelContainer = %DisclaimerBanner if has_node("%DisclaimerBanner") else null
@onready var disclaimer_title: Label = %DisclaimerTitle if has_node("%DisclaimerTitle") else null
@onready var disclaimer_sub: Label = %DisclaimerSub if has_node("%DisclaimerSub") else null
@onready var countdown_label: Label = %CountdownLabel if has_node("%CountdownLabel") else null
@onready var inverted_indicator: PanelContainer = %InvertedIndicator if has_node("%InvertedIndicator") else null
@onready var inverted_label: Label = %InvertedLabel if has_node("%InvertedLabel") else null
@onready var drunk_indicator: PanelContainer = %DrunkIndicator if has_node("%DrunkIndicator") else null

@onready var left_sidebar: Control = $Control/LeftMemeSideBar if has_node("Control/LeftMemeSideBar") else null
@onready var right_sidebar: Control = $Control/RightMemeSideBar if has_node("Control/RightMemeSideBar") else null
var _last_screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.best_score_changed.connect(_on_best_score_changed)
	GameState.meme_triggered.connect(_show_meme_card)
	GameState.milestone_reached.connect(_show_milestone)
	GameState.controls_inverted_warning_started.connect(_on_controls_warning_started)
	GameState.controls_inverted.connect(_on_controls_inverted)
	GameState.controls_restored.connect(_on_controls_restored)
	GameState.drunk_warning_started.connect(_on_drunk_warning_started)
	GameState.drunk_activated.connect(_on_drunk_activated)
	
	# Initial values
	_on_score_changed(GameState.score)
	_on_combo_changed(GameState.combo)
	_on_best_score_changed(GameState.best_score)
	if meme_card:
		meme_card.visible = false
	if milestone_banner:
		milestone_banner.visible = false
	if disclaimer_banner:
		disclaimer_banner.visible = false
	if inverted_indicator:
		inverted_indicator.visible = false
	if drunk_indicator:
		drunk_indicator.visible = false
		
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
	if new_score == 0:
		if inverted_indicator:
			inverted_indicator.visible = false
		if drunk_indicator:
			drunk_indicator.visible = false
		if disclaimer_banner:
			disclaimer_banner.visible = false

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
			combo_label.modulate = Color("c084fc") # Celestial starlight violet
		elif new_combo >= 5:
			combo_label.text = "★ ×" + str(new_combo) + " SUPER COMBO! ★"
			combo_label.modulate = Color("fbbf24") # Radiant amber topaz
		else:
			combo_label.text = "×" + str(new_combo) + " COMBO!"
			combo_label.modulate = Color("38bdf8") # Ice azure
		
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

func _on_controls_warning_started() -> void:
	if not disclaimer_banner or not countdown_label:
		return
	if disclaimer_title:
		disclaimer_title.text = "⚠️ -999 SOCIAL CREDIT ⚠️"
		disclaimer_title.label_settings.font_color = Color(1.0, 0.2, 0.2, 1.0)
	if disclaimer_sub:
		disclaimer_sub.text = "MALFUNCTION: CONTROLS INVERTING!"
		disclaimer_sub.label_settings.font_color = Color(1.0, 0.9, 0.2, 1.0)
	countdown_label.label_settings.font_color = Color(1.0, 1.0, 1.0, 1.0)
	countdown_label.label_settings.outline_color = Color(0.8, 0.0, 0.0, 1.0)

	disclaimer_banner.visible = true
	disclaimer_banner.modulate.a = 1.0
	disclaimer_banner.scale = Vector2(0.5, 0.5)
	disclaimer_banner.pivot_offset = disclaimer_banner.size / 2.0
	var tween = create_tween()
	tween.tween_property(disclaimer_banner, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(disclaimer_banner, "scale", Vector2(1.0, 1.0), 0.1)
	
	countdown_label.text = "⚡ INVERTING IN: 3 ⚡"
	var t1 = get_tree().create_timer(1.0)
	t1.timeout.connect(func():
		if is_instance_valid(countdown_label) and GameState.controls_warning_active:
			countdown_label.text = "⚡ INVERTING IN: 2 ⚡"
			GameState.trigger_effect(&"shake", 4.0)
	)
	var t2 = get_tree().create_timer(2.0)
	t2.timeout.connect(func():
		if is_instance_valid(countdown_label) and GameState.controls_warning_active:
			countdown_label.text = "⚡ INVERTING IN: 1 ⚡"
			GameState.trigger_effect(&"shake", 6.0)
	)
	var t3 = get_tree().create_timer(3.0)
	t3.timeout.connect(func():
		if is_instance_valid(countdown_label):
			countdown_label.text = "💥 CONTROLS INVERTED! 💥"
			GameState.trigger_effect(&"shake", 10.0)
			GameState.trigger_effect(&"screen_flash", Color(1.0, 0.1, 0.1, 0.5))
		if is_instance_valid(disclaimer_banner):
			var fade = create_tween()
			fade.tween_interval(0.8)
			fade.tween_property(disclaimer_banner, "modulate:a", 0.0, 0.3)
			fade.tween_callback(func(): disclaimer_banner.visible = false)
	)

func _on_controls_inverted() -> void:
	if inverted_indicator:
		inverted_indicator.visible = true
		inverted_indicator.modulate.a = 1.0
		if inverted_label:
			inverted_label.text = "🔄 REVERSED CONTROLS [5s] 🔄"
			for s in range(1, 5):
				var remaining = 5 - s
				var t = get_tree().create_timer(float(s))
				t.timeout.connect(func():
					if is_instance_valid(inverted_label) and GameState.are_controls_inverted:
						inverted_label.text = "🔄 REVERSED CONTROLS [" + str(remaining) + "s] 🔄"
				)
		var p_tween = create_tween().set_loops()
		p_tween.tween_property(inverted_indicator, "modulate:a", 0.45, 0.5)
		p_tween.tween_property(inverted_indicator, "modulate:a", 1.0, 0.5)

func _on_controls_restored() -> void:
	if inverted_indicator:
		if inverted_label:
			inverted_label.text = "✅ CONTROLS NORMAL! ✅"
		var fade = create_tween()
		fade.tween_interval(0.8)
		fade.tween_property(inverted_indicator, "modulate:a", 0.0, 0.35)
		fade.tween_callback(func():
			if is_instance_valid(inverted_indicator):
				inverted_indicator.visible = false
		)
	GameState.trigger_effect(&"screen_flash", Color(0.2, 1.0, 0.5, 0.3))

func _on_drunk_warning_started() -> void:
	if not disclaimer_banner or not countdown_label:
		return
	if disclaimer_title:
		disclaimer_title.text = "🍺 THAT GUY IS DRUNK! 🍺"
		disclaimer_title.label_settings.font_color = Color("818cf8")
	if disclaimer_sub:
		disclaimer_sub.text = "BUFF ACTIVE: +10% JUMP & WOBBLY SWAY!"
		disclaimer_sub.label_settings.font_color = Color("c084fc")
	countdown_label.label_settings.font_color = Color(1.0, 1.0, 1.0, 1.0)
	countdown_label.label_settings.outline_color = Color("4f46e5")
		
	disclaimer_banner.visible = true
	disclaimer_banner.modulate.a = 1.0
	disclaimer_banner.scale = Vector2(0.5, 0.5)
	disclaimer_banner.pivot_offset = disclaimer_banner.size / 2.0
	var tween = create_tween()
	tween.tween_property(disclaimer_banner, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(disclaimer_banner, "scale", Vector2(1.0, 1.0), 0.1)
	
	countdown_label.text = "🍺 BUFF IN: 3 🍺"
	var t1 = get_tree().create_timer(1.0)
	t1.timeout.connect(func():
		if is_instance_valid(countdown_label) and GameState.drunk_warning_active:
			countdown_label.text = "🍺 BUFF IN: 2 🍺"
			GameState.trigger_effect(&"shake", 3.0)
	)
	var t2 = get_tree().create_timer(2.0)
	t2.timeout.connect(func():
		if is_instance_valid(countdown_label) and GameState.drunk_warning_active:
			countdown_label.text = "🍺 BUFF IN: 1 🍺"
			GameState.trigger_effect(&"shake", 5.0)
	)
	var t3 = get_tree().create_timer(3.0)
	t3.timeout.connect(func():
		if is_instance_valid(countdown_label):
			countdown_label.text = "🥴 DRUNK BUFF ENGAGED! 🥴"
			GameState.trigger_effect(&"shake", 8.0)
			GameState.trigger_effect(&"screen_flash", Color(0.5, 0.3, 0.9, 0.4))
		if is_instance_valid(disclaimer_banner):
			var fade = create_tween()
			fade.tween_interval(0.8)
			fade.tween_property(disclaimer_banner, "modulate:a", 0.0, 0.3)
			fade.tween_callback(func(): disclaimer_banner.visible = false)
	)

func _on_drunk_activated() -> void:
	if drunk_indicator:
		drunk_indicator.visible = true
		var p_tween = create_tween().set_loops()
		p_tween.tween_property(drunk_indicator, "modulate:a", 0.45, 0.6)
		p_tween.tween_property(drunk_indicator, "modulate:a", 1.0, 0.6)
