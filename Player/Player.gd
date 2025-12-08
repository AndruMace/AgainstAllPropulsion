class_name Player
extends CharacterBody3D

@export var base_speed := 10.0
var speed := 10.0
@export var jump_height := 1.0
@export var max_hp := 100
@export var aim_multi := 0.7

@onready var dmg_animation_player: AnimationPlayer = $DamageTexture/AnimationPlayer
@onready var game_over_menu: GameOverMenu = $GameOverMenu
@onready var ammo_handler: AmmoHandler = %AmmoHandler

@onready var main_camera_3d: Camera3D = $Camera3D
@onready var default_fov = main_camera_3d.fov

@onready var weapon_cam: Camera3D = $SubViewportContainer/SubViewport/WeaponCam
@onready var default_weapon_fov = weapon_cam.fov

# Multiplayer
var client_id: int = -1
var window_client_id: int = -1
var is_local_player: bool = false
var is_own_window_client: bool = false

@onready var position_synchronizer: PropertySynchronizer = $PropertySynchronizer

var last_checkpoint_pos := Vector3.ZERO
var aim_animation_speed := 20
var change_velocity := true
var mouse_motion := Vector2.ZERO
var is_flying := false # New variable to track flying state
var mouse_sens := 0.005

var curr_hp := max_hp:
	set(value):
		if value < curr_hp:
			dmg_animation_player.stop(false)
			dmg_animation_player.play("take_damage")
		curr_hp = value
		if curr_hp < 1:
			get_tree().paused = true
			game_over_menu.game_over()


func _ready() -> void:
	window_client_id = GDSync.get_client_id()


func _input(event: InputEvent) -> void:
	# Only process input for local player
	if not is_local_player:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			mouse_motion = -event.relative * PlayerVariables.mouse_sense

	#if Input.is_action_just_pressed("ui_cancel"):
	# if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
	# 	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# else:
	# 	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.is_action_just_pressed("fly") and OS.is_debug_build():
		is_flying = !is_flying
		if is_flying:
			velocity = Vector3.ZERO
			speed = 50 # Reset momentum when enabling flight

	if Input.is_action_just_pressed("reset") and last_checkpoint_pos:
		position = last_checkpoint_pos
		velocity = Vector3.ZERO
		# Pause interpolation when teleporting
		if position_synchronizer:
			position_synchronizer.pause_interpolation(0.1)


func handle_cam_rotation() -> void:
	rotate_y(mouse_motion.x)
	$Camera3D.rotate_x(mouse_motion.y)
	$Camera3D.rotation_degrees.x = clampf($Camera3D.rotation_degrees.x, -90.0, 90.0)
	mouse_motion = Vector2.ZERO


func setup_multiplayer() -> void:
	print("[Player] setup_multiplayer() called for ", name, " client_id=", client_id)
	# Check if GDSync is available
	if not has_node("/root/GDSync"):
		print("[Player] GDSync not found, running in single-player mode")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		main_camera_3d.current = true
		weapon_cam.current = true
		return

	var gdsync = get_node("/root/GDSync")

	# If GDSync isn't active yet, or client_id isn't set, default to local player
	# This handles the case where the player is set up before GDSync connects
	if not gdsync.is_active() or client_id == -1:
		print("[Player] GDSync not active or client_id not set, defaulting to local player")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		main_camera_3d.current = true
		weapon_cam.current = true
		print("[Player] Camera enabled (defaulting to local)")
		return

	var my_client_id = gdsync.get_client_id()
	print("[Player] ", name, " client_id=", client_id, " my_client_id=", my_client_id)

	# Determine if this is the local player
	is_local_player = (client_id == my_client_id)
	print("[Player] ", name, " is_local_player=", is_local_player)

	# Only enable input and camera for local player
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Enable camera for local player
		main_camera_3d.current = true
		weapon_cam.current = true
	else:
		# Disable camera for remote players
		main_camera_3d.current = false
		weapon_cam.current = false
		# Disable UI elements for remote players
		if has_node("SubViewportContainer"):
			var svc = get_node("SubViewportContainer")
			svc.visible = false
			svc.process_mode = Node.PROCESS_MODE_DISABLED
			# Move weapon meshes to layer 1 so main camera sees them (not WeaponCam)
			var weapon_handler = svc.get_node_or_null("SubViewport/WeaponCam/WeaponHandler")
			if weapon_handler:
				_set_layers_recursive(weapon_handler, 1)
			print("[Player] Setup remote player ", name, " weapons on layer 1")
		if has_node("CenterContainer"):
			get_node("CenterContainer").visible = false
		if has_node("MarginContainer"):
			get_node("MarginContainer").visible = false


func _set_layers_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_layers_recursive(child, layer)


func set_client_id(new_client_id: int) -> void:
	if client_id != -1 or client_id == new_client_id:
		return

	client_id = new_client_id
	setup_multiplayer()


func _process(delta: float) -> void:
	# Only process input-related logic for local player
	if not is_local_player:
		return

	if Input.is_action_pressed("sprint") and is_on_floor():
		speed = base_speed * 1.5
	elif is_on_floor():
		speed = base_speed
	if Input.is_action_pressed("aim"):
		main_camera_3d.fov = lerp(
			main_camera_3d.fov,
			default_fov * aim_multi,
			aim_animation_speed * delta,
		)
		weapon_cam.fov = lerp(
			weapon_cam.fov,
			default_weapon_fov * aim_multi,
			aim_animation_speed * delta,
		)
	elif main_camera_3d.fov != default_fov:
		main_camera_3d.fov = lerp(
			main_camera_3d.fov,
			default_fov,
			aim_animation_speed * delta,
		)
		weapon_cam.fov = lerp(
			weapon_cam.fov,
			default_weapon_fov,
			aim_animation_speed * delta,
		)


func _physics_process(delta: float) -> void:
	# Only handle movement for local player
	# Remote players will have their position synchronized via PropertySynchronizer
	if not is_local_player:
		# Remote players still need to apply gravity and move
		# But they don't process input
		# if not is_flying and not is_on_floor():
		# 	velocity += get_gravity() * delta * 1.2
		# move_and_slide()
		return

	handle_cam_rotation()

	if is_flying:
		var fly_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var vertical := 0.0
		if Input.is_action_pressed("jump"):
			vertical += 3.0
		if Input.is_action_pressed("move_back"):
			vertical -= 3.0

		var direction := (transform.basis * Vector3(fly_input.x, 0, fly_input.y)).normalized()
		direction.y = vertical
		velocity = direction.normalized() * speed
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta * 1.2

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = sqrt(jump_height * 2.0 * -get_gravity().y)
			#velocity.y += 5

		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		#if direction:
		if direction and is_on_floor():
			var control_strength := 0.7 # Lower = less control
			velocity.x = move_toward(velocity.x, direction.x * speed, control_strength)
			velocity.z = move_toward(velocity.z, direction.z * speed, control_strength)
		elif direction and !is_on_floor():
			var control_strength := 0.3 # Lower = less control
			velocity.x = move_toward(velocity.x, direction.x * speed, control_strength)
			velocity.z = move_toward(velocity.z, direction.z * speed, control_strength)
		elif change_velocity and is_on_floor():
			velocity.x = move_toward(velocity.x, 0, speed / 2)
			velocity.z = move_toward(velocity.z, 0, speed / 2)

	move_and_slide()


func blasted() -> void:
	change_velocity = false
	await get_tree().create_timer(1.0).timeout
	if is_on_floor():
		change_velocity = true
	else:
		blasted()
