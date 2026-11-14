extends Node2D

@onready var robot: CharacterBody2D = $Robot

func _ready() -> void:
	GameState.start_game()
