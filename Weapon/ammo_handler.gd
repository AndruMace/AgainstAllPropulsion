class_name AmmoHandler extends Node

@export var ammo_label: Label

enum ammo_type {
	LG_BULLET, 
	SM_BULLET
}

var ammo_storage := {
	ammo_type.LG_BULLET: 100,
	ammo_type.SM_BULLET: 100,
}

func has_ammo(type: ammo_type) -> bool:
	return ammo_storage[type] > 0

func use_ammo(type: ammo_type) -> void:
	if has_ammo(type):
		ammo_storage[type] -= 1
		update_label(type)

func add_ammo(type: ammo_type, amount: int) -> void:
	ammo_storage[type] += amount
	update_label(type)

func update_label(type: ammo_type) -> void:
	ammo_label.text = str(ammo_storage[type])
