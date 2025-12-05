extends Timer

@onready var timer_label: Label = $"../MarginContainer/TimerLabel"
var elapsed_time = 0.0
var is_timer_running = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_timer_running = true
	wait_time = 0.01
	start()
	
func stop_timer():
	is_timer_running = false
	stop()

func reset_timer():
	elapsed_time = 0.0

func _on_timeout() -> void:
	if is_timer_running:
		elapsed_time += 0.01
		var time_fmt = update_display()
		PlayerVariables.level_time = elapsed_time
		timer_label.text = time_fmt

func update_display():
	var minutes = int(elapsed_time / 60)
	var seconds = int(elapsed_time) % 60
	var milliseconds = int((elapsed_time - int(elapsed_time)) * 100)
	return "%02d:%02d:%02d" % [minutes, seconds, milliseconds]

func get_final_time():
	return elapsed_time
