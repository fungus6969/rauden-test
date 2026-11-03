## wave_manager.gd - Progressive Hilichurl Wave Spawner (Godot 4.3+)
class_name WaveManager
extends Node3D

signal wave_started(wave_number: int, total_enemies: int)
signal wave_cleared(wave_number: int)
signal all_waves_completed
signal enemy_count_changed(remaining: int)

@export_group("Wave Configuration")
@export var infinite_mode: bool = true
@export var total_waves: int = 5
@export var intermission_delay: float = 3.5
@export var hilichurl_scene: PackedScene

@export_group("Spawn Anchors")
@export var spawn_points: Array[Node3D] = []
@export var spawn_vfx_scene: PackedScene

var current_wave_index: int = 0
var active_enemies: Array[HilichurlEnemy] = []
var is_wave_active: bool = false
var intermission_timer: float = 0.0


func _ready() -> void:
	intermission_timer = 1.5


func _process(delta: float) -> void:
	if not is_wave_active and (infinite_mode or current_wave_index < total_waves):
		intermission_timer -= delta
		if intermission_timer <= 0.0:
			start_next_wave()


func start_next_wave() -> void:
	current_wave_index += 1
	is_wave_active = true
	var enemy_count: int = mini(10, 2 + int((current_wave_index - 1) * 0.75))
	wave_started.emit(current_wave_index, enemy_count)
	
	for i in range(enemy_count):
		var delay = i * 0.45
		get_tree().create_timer(delay).timeout.connect(func(): _spawn_single_enemy(i))


func _spawn_single_enemy(index: int) -> void:
	if not hilichurl_scene:
		return

	var enemy_inst = hilichurl_scene.instantiate() as HilichurlEnemy
	var spawn_pos = Vector3.ZERO
	if spawn_points.size() > 0:
		var anchor = spawn_points[index % spawn_points.size()]
		spawn_pos = anchor.global_position
	else:
		var side = 1.0 if (index % 2 == 0) else -1.0
		spawn_pos = Vector3(side * (5.0 + index * 1.2), 0.0, randf_range(-2.0, 2.0))
		
	enemy_inst.global_position = spawn_pos
	get_parent().add_child(enemy_inst)
	active_enemies.append(enemy_inst)
	
	if spawn_vfx_scene:
		var vfx = spawn_vfx_scene.instantiate() as Node3D
		vfx.global_position = spawn_pos
		get_parent().add_child(vfx)
	
	enemy_inst.enemy_died.connect(func(): _on_enemy_defeated(enemy_inst))
	enemy_count_changed.emit(active_enemies.size())


func _on_enemy_defeated(enemy: HilichurlEnemy) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)
		enemy_count_changed.emit(active_enemies.size())

	if active_enemies.is_empty() and is_wave_active:
		is_wave_active = false
		wave_cleared.emit(current_wave_index)
		
		if current_wave_index >= total_waves:
			all_waves_completed.emit()
		else:
			intermission_timer = intermission_delay
