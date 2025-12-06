class_name WeaponHandler
extends Node3D

@export var weapon_1: HitscanWeapon
@export var weapon_2: HitscanWeapon
@export var weapon_3: ProjectileWeapon

@onready var player: Player = owner


func _ready() -> void:
	# Defer equip until player.is_local_player is set
	await get_tree().process_frame
	if not player.is_local_player:
		set_process_unhandled_input(false)
		return

	equip(weapon_3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("weapon_1"):
		equip(weapon_1)
	if event.is_action("weapon_2"):
		equip(weapon_2)

	if event.is_action_pressed("next_weapon"):
		next_weapon()
	if event.is_action_pressed("prev_weapon"):
		prev_weapon()

	if event.is_action_pressed("fire") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func equip(active_weapon: Node3D) -> void:
	active_weapon.ammo_handler.update_label(active_weapon.ammo_type)
	for child in get_children():
		child.visible = (child == active_weapon)
		child.set_process(child == active_weapon)


func next_weapon() -> void:
	var idx = get_current_index()
	idx = wrapi(idx + 1, 0, get_child_count())
	equip(get_child(idx))


func prev_weapon() -> void:
	var idx = get_current_index()
	idx = wrapi(idx - 1, 0, get_child_count())
	equip(get_child(idx))


func get_current_index() -> int:
	for index in get_child_count():
		if get_child(index).visible:
			return index

	get_tree().quit()
	return -1
