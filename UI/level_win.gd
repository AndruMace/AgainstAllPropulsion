extends Control

@onready var level_time_label: Label = $GridContainer/LevelTimeLabel
@onready var rank_label: Label = $GridContainer/RankLabel
const LEVEL_2 = preload("res://level_2.tscn")

func get_rank(final_time):
	if final_time < 60.0:
		return "Gold"
	elif final_time < 120.0:
		return "Silver"
	elif final_time < 210.0:
		return "Bronze"
	else:
		return "No medal, try harder next time"

func _ready() -> void:
	visible = false

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func end_level() -> void:
	level_time_label.text = PlayerVariables.format_level_time(PlayerVariables.level_time)
	rank_label.text = get_rank(PlayerVariables.level_time)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_continue_button_pressed() -> void:
	get_tree().change_scene_to_packed(LEVEL_2)
