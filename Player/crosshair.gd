class_name Crosshair extends Control

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3, Color.DIM_GRAY)
	draw_circle(Vector2.ZERO, 2, Color.WHITE)
