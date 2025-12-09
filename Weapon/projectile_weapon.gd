class_name ProjectileWeapon
extends Node3D

@export var fully_auto := true
@export var recoil_amount := 2
@export var shots_per_second := 1.0
@export var weapon_mesh: Node3D
@export var damage := 7.0
@export var muzzle_flash: GPUParticles3D
@export var sparks: PackedScene
@export var ammo_handler: AmmoHandler
@export var ammo_type: AmmoHandler.ammo_type
@export var projectile: PackedScene

@onready var timer: Timer = $CoolDownTimer
@onready var weapon_start_pos := weapon_mesh.position
@onready var player: Player = $"../../../../.."
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var rocket_instantiator: NodeInstantiator = player.get_node("RocketInstantiator")


func _ready() -> void:
	await get_tree().process_frame
	if not player.is_local_player:
		set_process(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fully_auto:
		if Input.is_action_pressed("fire"):
			if timer.is_stopped():
				shoot()
	else:
		if Input.is_action_just_pressed("fire"):
			if timer.is_stopped():
				shoot()

	weapon_mesh.position = lerp(weapon_mesh.position, weapon_start_pos, delta * 10)


func shoot() -> void:
	if !ammo_handler.has_ammo(ammo_type):
		return

	ammo_handler.use_ammo(ammo_type)
	muzzle_flash.restart()
	timer.start(1.0 / shots_per_second)
	weapon_mesh.position.z += recoil_amount

	audio_stream_player.play(0.0)
	var missile := rocket_instantiator.instantiate_node()
	# Set ownership so PropertySynchronizer syncs from this client
	var client_id = GDSync.get_client_id()
	GDSync.set_gdsync_owner(missile, client_id)
	missile.get_node("PropertySynchronizer")._update_sync_mode()
	# Set synced properties in same frame - auto-synced via sync_starting_changes
	missile.global_position = get_parent_node_3d().global_position
	missile.rotation.y = player.rotation.y
	missile.rotation_degrees.x = player.main_camera_3d.rotation_degrees.x - 90
