class_name Checkpoint extends Node3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		var client_id = -1
		if has_node("/root/GDSync"):
			var gdsync = get_node("/root/GDSync")
			if gdsync.is_active():
				client_id = gdsync.get_client_id()
		print("[Client ID: ", client_id, "] Checkpoint")
		body.last_checkpoint_pos = Vector3(position.x, position.y + 2, position.z)
		var activated_mat := StandardMaterial3D.new()
		activated_mat.albedo_color = Color.GREEN
		$CSGCylinder3D.material = activated_mat
