class_name Player extends CharacterBody3D

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

var last_checkpoint_pos := Vector3.ZERO
var aim_animation_speed := 20
var change_velocity := true
var mouse_motion := Vector2.ZERO
var is_flying := false  # New variable to track flying state
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_motion = -event.relative * PlayerVariables.mouse_sense

	#if Input.is_action_just_pressed("ui_cancel"):
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if Input.is_action_just_pressed("fly") and OS.is_debug_build():
		is_flying = !is_flying
		if is_flying:
			velocity = Vector3.ZERO
			speed = 50  # Reset momentum when enabling flight
			
	if Input.is_action_just_pressed("reset") and last_checkpoint_pos:
		position = last_checkpoint_pos
		velocity = Vector3.ZERO

func handle_cam_rotation() -> void:
	rotate_y(mouse_motion.x)
	$Camera3D.rotate_x(mouse_motion.y)
	$Camera3D.rotation_degrees.x = clampf($Camera3D.rotation_degrees.x, -90.0, 90.0)
	mouse_motion = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mouse_sens

func _process(delta: float) -> void:
	if Input.is_action_pressed("sprint") and is_on_floor():
		speed = base_speed * 1.5
	elif is_on_floor():
		speed = base_speed
	if Input.is_action_pressed("aim"):
		main_camera_3d.fov = lerp(
			main_camera_3d.fov, 
			default_fov * aim_multi, 
			aim_animation_speed * delta
		)
		weapon_cam.fov = lerp(
			weapon_cam.fov, 
			default_weapon_fov * aim_multi, 
			aim_animation_speed * delta
		)
	elif main_camera_3d.fov != default_fov:
		main_camera_3d.fov = lerp(
			main_camera_3d.fov, 
			default_fov, 
			aim_animation_speed * delta
		)
		weapon_cam.fov = lerp(
			weapon_cam.fov, 
			default_weapon_fov, 
			aim_animation_speed * delta
		)

func _physics_process(delta: float) -> void:
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
			var control_strength := 0.7  # Lower = less control
			velocity.x = move_toward(velocity.x, direction.x * speed, control_strength)
			velocity.z = move_toward(velocity.z, direction.z * speed, control_strength)

		elif direction and !is_on_floor():
			var control_strength := 0.3  # Lower = less control
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
