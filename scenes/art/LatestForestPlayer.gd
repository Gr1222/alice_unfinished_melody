extends CharacterBody2D

const Art = preload("res://scripts/UserArt.gd")
var facing := Vector2.DOWN

func _draw() -> void:
	Art.draw_character(self, Vector2.ZERO, facing, false, false, 42.0)
