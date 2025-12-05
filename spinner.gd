extends StaticBody3D

@export var degrees_per_second: float = 30.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var rads = deg_to_rad(degrees_per_second * delta)
	rotate_z(rads)
