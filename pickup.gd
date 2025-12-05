extends Area3D

@export var pickup_ammo_type: AmmoHandler.ammo_type
@export var ammo_qty := 100

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.ammo_handler.add_ammo(pickup_ammo_type, ammo_qty)
		#if pickup_ammo_type ==:
			#body.ammo_handler.update_label(pickup_ammo_type)
		queue_free()
