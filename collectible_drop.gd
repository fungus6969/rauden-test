## collectible_drop.gd - Inazuma Healing Item Drop (Godot 4.3+)
## Dropped upon enemy defeat. Stays in world for 20 seconds before despawning.
## Heals the player upon proximity or contact.
class_name CollectibleDrop
extends Area3D

signal item_collected(item_name: String, heal_amount: float)
signal item_expired

@export var heal_amount: float = 35.0
@export var lifetime: float = 20.0 ## 20 seconds cooldown window to collect
@export var attraction_radius: float = 2.8
@export var attraction_speed: float = 8.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var timer_label: Label3D = $TimerLabel3D
@onready var particles: GPUParticles3D = $GlowParticles

var time_elapsed: float = 0.0
var target_player: Player = null
var is_collected: bool = false
var initial_y: float = 0.0


func _ready() -> void:
	initial_y = global_position.y
	# Connect collision with player hurtbox or player body
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if is_collected:
		return
		
	time_elapsed += delta
	lifetime -= delta
	
	# Floating bobbing animation (Genshin Impact collectible style)
	position.y = initial_y + sin(time_elapsed * 3.5) * 0.15
	rotate_y(1.5 * delta)
	
	# Update floating 20s countdown label
	if timer_label:
		timer_label.text = "%.1fs" % max(0.0, lifetime)
		if lifetime <= 5.0:
			# Flashing red warning when near expiration
			timer_label.modulate = Color(1.0, 0.3, 0.3, 0.9) if int(time_elapsed * 6) % 2 == 0 else Color(1.0, 1.0, 1.0, 0.5)

	# 20 Seconds Expired Check
	if lifetime <= 0.0:
		item_expired.emit()
		queue_free()
		return

	# Magnetic attraction toward nearby player
	_process_magnetic_pickup(delta)


func _process_magnetic_pickup(delta: float) -> void:
	if not target_player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0] as Player
			if p and p.global_position.distance_to(global_position) <= attraction_radius:
				target_player = p

	if target_player:
		global_position = global_position.lerp(target_player.global_position + Vector3(0, 0.8, 0), attraction_speed * delta)
		if global_position.distance_to(target_player.global_position) < 0.6:
			_collect(target_player)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_collect(body as Player)


func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player_hurtbox"):
		var p = area.get_parent() as Player
		if p:
			_collect(p)


func _collect(player: Player) -> void:
	if is_collected:
		return
	is_collected = true
	
	# Heal Player
	player.heal(heal_amount)
	item_collected.emit("Naku Weed Herb", heal_amount)
	
	# Free from scene
	queue_free()
