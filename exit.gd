class_name Exit extends Node3D

func _ready() -> void:
	$LevelWinMenu.visible = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	print("Player won!")
	if body is Player:
		$LevelWinMenu.end_level()
