extends Timer

@onready var timer_label: Label = $"../MarginContainer/TimerLabel"
var start_time: int = 0
var accumulated_time: float = 0.0 # Time accumulated before pauses
var is_timer_running = false


func _ready() -> void:
	wait_time = 0.05 # Display update rate (doesn't affect accuracy)
	start_timer()


func start_timer():
	start_time = Time.get_ticks_msec()
	is_timer_running = true
	start()


func stop_timer():
	if is_timer_running:
		accumulated_time = get_elapsed_time()
	is_timer_running = false
	stop()


func reset_timer():
	accumulated_time = 0.0
	start_time = Time.get_ticks_msec()


func get_elapsed_time() -> float:
	if is_timer_running:
		return accumulated_time + (Time.get_ticks_msec() - start_time) / 1000.0
	return accumulated_time


func _on_timeout() -> void:
	if is_timer_running:
		var elapsed = get_elapsed_time()
		PlayerVariables.level_time = elapsed
		timer_label.text = format_time(elapsed)


func format_time(time_sec: float) -> String:
	var minutes = int(time_sec / 60)
	var seconds = int(time_sec) % 60
	var milliseconds = int((time_sec - int(time_sec)) * 100)
	return "%02d:%02d:%02d" % [minutes, seconds, milliseconds]


func get_final_time() -> float:
	return get_elapsed_time()
