extends Area3D
@onready var explosion: GPUParticles3D = $Explosion
@onready var smoke: GPUParticles3D = $Smoke
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += transform.basis.y / 5

func _on_body_entered(body: Node3D) -> void:
	var space_state = get_world_3d().direct_space_state
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 10
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform.origin = position
	query.shape = sphere_shape
	
	var result = space_state.intersect_shape(query, 32)
	for hit in result:
		var hit_body = hit.get("collider")
		if hit_body is RigidBody3D:
			var body_pos = hit_body.position
			var to_body = body_pos - position
			var direction = to_body.normalized()
			var distance = max(to_body.length(), 1.0)

			var force = 10.0
			var impulse = direction * (force / distance)
			var offset_world = body_pos + direction * 1.25 # Slightly outside center
			var offset_local = hit_body.to_local(offset_world)
			hit_body.apply_impulse(impulse, Vector3.ZERO)
		elif hit_body is CharacterBody3D:
			var body_pos = hit_body.position
			var to_body = body_pos - position
			var direction = to_body.normalized()
			var distance = max(to_body.length(), 1.0)
			#var distance = to_body.length()
			var force = 15.0
			var impulse = direction * (force / distance)

			# For CharacterBody3D, we need to modify its velocity directly
			# Check if the CharacterBody3D has a velocity property
			if hit_body.has_method("blasted"):
				var current_velocity = hit_body.get_velocity()
				#var modded_vel = Vector3(
					#current_velocity.x * 1.25, 
					#current_velocity.y,
					#current_velocity.z * 1.25)
				# Add the impulse to the current velocity
				var new_velocity = current_velocity + impulse
				hit_body.blasted()
				hit_body.set_velocity(new_velocity)
				hit_body.move_and_slide()

	audio_stream_player_3d.play(0.0)
	explosion.emitting = true
	smoke.emitting = true
	$CollisionShape3D.disabled = true
	$missle_mesh.visible = false
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
	
