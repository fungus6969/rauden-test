## hitbox_3d.gd - Modular Hitbox Area3D Component (Godot 4.3+)
class_name Hitbox3D
extends Area3D

signal hit_landed(target_hurtbox: Area3D, damage_dealt: float)

@export var base_damage: float = 10.0
@export var is_electro: bool = true
@export var knockback_direction: Vector3 = Vector3(1, 0.3, 0)

var current_damage: float = 10.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_damage_properties(dmg: float, electro: bool) -> void:
	current_damage = dmg
	is_electro = electro


func _on_area_entered(hurtbox: Area3D) -> void:
	if not monitoring or not hurtbox.monitorable:
		return
		
	if hurtbox.has_method("receive_hit"):
		hurtbox.receive_hit(current_damage, is_electro, global_transform.basis * knockback_direction)
		hit_landed.emit(hurtbox, current_damage)
