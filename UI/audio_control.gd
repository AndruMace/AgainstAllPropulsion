extends HSlider

@export var audio_bus: String

var bus_id := 0

func _ready() -> void:
	bus_id = AudioServer.get_bus_index(audio_bus)

func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(bus_id, db)
	
