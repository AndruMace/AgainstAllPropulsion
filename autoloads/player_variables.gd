extends Node

var mouse_sense := 0.005
var level_time := 0.0

func format_level_time(time ):
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	var milliseconds = int((time - int(time)) * 100)
	return "%02d:%02d:%0d" % [minutes, seconds, milliseconds]
