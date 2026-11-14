extends CanvasLayer
class_name HUD

@onready var score_label: Label = $Control/MarginContainer/TopBar/ScoreContainer/ScoreLabel
@onready var best_label: Label = $Control/MarginContainer/TopBar/BestContainer/BestLabel
@onready var combo_container: Control = $Control/ComboContainer
@onready var combo_label: Label = $Control/ComboContainer/ComboLabel

@onready var meme_card: PanelContainer = $Control/MemeCard
@onready var meme_label: Label = $Control/MemeCard/MarginContainer/MemeLabel
var meme_tween: Tween

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.best_score_changed.connect(_on_best_score_changed)
	GameState.meme_triggered.connect(_show_meme_card)
	
	# Initial values
	_on_score_changed(GameState.score)
	_on_combo_changed(GameState.combo)
	_on_best_score_changed(GameState.best_score)
	if meme_card:
		meme_card.visible = false

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
		combo_label.text = "×" + str(new_combo) + " COMBO!"
		
		# Punchy pop animation on increment
		var tween = create_tween()
		combo_label.pivot_offset = combo_label.size / 2.0
		combo_label.scale = Vector2(1.4, 1.4)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
