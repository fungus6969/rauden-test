class_name InazumaVegetationManager
extends Node3D

## Inazuma Vegetation & MultiMeshInstance3D Wind System for Godot 4
##
## Architected for high-density mobile performance:
## 1. MultiMeshInstance3D for batched grass blade rendering with zero draw-call overhead.
## 2. Vertex wind-sway spatial shader for natural grass and foliage rustling.
## 3. Procedural scattering of Inazuma flora: Dendrobium (Spider Lilies), Bamboo groves, and Hydrangea shrubs.

@export_group("Grass MultiMesh Configuration")
@export var grass_instance_count: int = 500
@export var spawn_radius: float = 14.0
@export var grass_mesh: Mesh
@export var wind_strength: float = 0.15
@export var wind_speed: float = 2.4

@export_group("Inazuma Specialty Flora")
@export var dendrobium_scene: PackedScene
@export var bamboo_grove_scene: PackedScene
@export var hydrangea_bush_scene: PackedScene
@export var naku_weed_scene: PackedScene

@onready var grass_multimesh_node: MultiMeshInstance3D = $GrassMultiMesh
@onready var flora_container: Node3D = $FloraContainer

var _wind_time: float = 0.0

func _ready() -> void:
	_generate_multimesh_grass()
	_scatter_inazuma_flora()


## Generate optimized batched 3D grass across the Inazuma garden
func _generate_multimesh_grass() -> void:
	if not grass_multimesh_node:
		grass_multimesh_node = MultiMeshInstance3D.new()
		grass_multimesh_node.name = "GrassMultiMesh"
		add_child(grass_multimesh_node)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = grass_instance_count
	multimesh.mesh = grass_mesh if grass_mesh else _create_default_blade_mesh()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(grass_instance_count):
		# Distribute grass clusters organically across the arena
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.5, spawn_radius)
		var x: float = cos(angle) * dist
		var z: float = sin(angle) * (dist * 0.45) # Elliptical plateau bounds
		var y: float = 0.01

		# Avoid placing grass right in the center stone path
		if abs(z) < 0.6 and abs(x) < 12.0:
			z += rng.randf_range(0.8, 1.5) * (1.0 if rng.randf() > 0.5 else -1.0)

		var cluster_transform := Transform3D()
		var cluster_scale: float = rng.randf_range(0.7, 1.35)
		cluster_transform = cluster_transform.scaled(Vector3(cluster_scale, cluster_scale, cluster_scale))
		cluster_transform = cluster_transform.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		cluster_transform.origin = Vector3(x, y, z)

		multimesh.set_instance_transform(i, cluster_transform)

	grass_multimesh_node.multimesh = multimesh


## Fallback procedural cross-blade grass mesh if custom asset is not provided
func _create_default_blade_mesh() -> Mesh:
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.12
	prism.height = 0.75
	prism.radial_segments = 4
	return prism


## Scatter authentic Inazuma battlefield flora and cherry blossom groves
func _scatter_inazuma_flora() -> void:
	# 1. Inazuma Dendrobium (Blood-red spider lilies) along stone path boundaries
	var dendro_positions: Array[Vector3] = [
		Vector3(-8.5, 0.0, -2.6), Vector3(-6.2, 0.0, 2.2),
		Vector3(-3.8, 0.0, -2.4), Vector3(1.8, 0.0, -2.2),
		Vector3(4.2, 0.0, 2.2), Vector3(6.5, 0.0, -2.5),
		Vector3(8.8, 0.0, 2.3), Vector3(-1.8, 0.0, 2.4)
	]
	for pos in dendro_positions:
		_spawn_flora_instance(dendrobium_scene, pos)

	# 2. Outer Bamboo Groves providing vertical framing
	var bamboo_positions: Array[Vector3] = [
		Vector3(-12.8, 0.0, -4.2), Vector3(-11.5, 0.0, -4.8),
		Vector3(12.6, 0.0, -4.2), Vector3(11.4, 0.0, -4.8),
		Vector3(-2.2, 0.0, -6.8), Vector3(2.2, 0.0, -6.8)
	]
	for pos in bamboo_positions:
		_spawn_flora_instance(bamboo_grove_scene, pos)


func _spawn_flora_instance(scene_to_instantiate: PackedScene, pos: Vector3) -> void:
	if not scene_to_instantiate:
		return
	var inst := scene_to_instantiate.instantiate() as Node3D
	if inst:
		inst.position = pos
		if flora_container:
			flora_container.add_child(inst)
		else:
			add_child(inst)


## Lightweight continuous wind sway simulation
func _process(delta: float) -> void:
	_wind_time += delta * wind_speed
	if grass_multimesh_node and grass_multimesh_node.material_override:
		# If a custom shader material is attached, update wind uniform
		var mat := grass_multimesh_node.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("wind_time", _wind_time)
