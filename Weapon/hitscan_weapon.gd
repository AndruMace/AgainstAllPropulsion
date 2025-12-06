class_name HitscanWeapon
extends Node3D

@export var fully_auto := true
@export var recoil_amount := 0.05
@export var shots_per_second := 14.0
@export var weapon_mesh: Node3D
@export var damage := 7.0
@export var muzzle_flash: GPUParticles3D
@export var sparks: PackedScene
@export var ammo_handler: AmmoHandler
@export var ammo_type: AmmoHandler.ammo_type
#@export var aim_multi := 0.7 TODO: add weapon dependent zoom multipliers
@onready var ray_cast_3d: RayCast3D = $RayCast3D
@onready var timer: Timer = $CoolDownTimer
@onready var weapon_start_pos := weapon_mesh.position
@onready var player: Player = owner


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
	var collider = ray_cast_3d.get_collider()

	if collider:
		var spark = sparks.instantiate()
		add_child(spark)
		spark.global_position = ray_cast_3d.get_collision_point()
