class_name PauseMenu extends Control

var is_paused := false:
	set(val):
		is_paused = val
		get_tree().paused = is_paused
		visible = is_paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	$Settings.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		is_paused = !is_paused


func _on_resume_button_pressed() -> void:
	is_paused = false


func _on_settings_button_pressed() -> void:
	$Settings.visible = true


func _on_quit_button_pressed() -> void:
	get_tree().quit()

# Back from settings to menu
func _on_back_button_pressed() -> void:
	$Settings.visible = false


func _on_mouse_sensitivty_value_changed(value: float) -> void:
	PlayerVariables.mouse_sense = value
