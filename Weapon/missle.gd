extends Area3D

@onready var explosion: GPUParticles3D = $Explosion
@onready var smoke: GPUParticles3D = $Smoke
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _exploded := false
var _is_host := false


func _ready() -> void:
	GDSync.expose_func(_destroy_remote)


func _multiplayer_ready() -> void:
	# Called after properties are synced on remote clients
	_is_host = GDSync.is_host()


func _process(_delta: float) -> void:
	position += transform.basis.y / 5


func _on_body_entered(_body: Node3D) -> void:
	if !_is_host:
		return
	if _exploded:
		return
	_exploded = true

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
			var force = 15.0
			var impulse = direction * (force / distance)

			if hit_body.has_method("apply_explosion_impulse"):
				GDSync.call_func_on(hit_body.client_id, hit_body.apply_explosion_impulse, [impulse])

	_do_explosion_effects()
	GDSync.call_func(_destroy_remote)
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _do_explosion_effects() -> void:
	audio_stream_player_3d.play(0.0)
	explosion.emitting = true
	smoke.emitting = true
	$CollisionShape3D.disabled = true
	$missle_mesh.visible = false


func _destroy_remote() -> void:
	_exploded = true
	_do_explosion_effects()
	await get_tree().create_timer(1.0).timeout
	queue_free()
