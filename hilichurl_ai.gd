## hilichurl_ai.gd - Complete Hilichurl Enemy AI (Godot 4.3+)
class_name HilichurlEnemy
extends CharacterBody3D

signal health_changed(current_hp: float, max_hp: float)
signal enemy_damaged(amount: float, is_electro: bool)
signal enemy_died

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK_WINDUP,
	ATTACK_SWING,
	RECOVERY,
	HURT,
	DEAD
}

@export_group("Stats & Speeds")
@export var max_health: float = 80.0
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 4.2
@export var attack_damage: float = 16.0
@export var knockback_force: float = 5.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

@export_group("Item Drop on Death")
@export var drop_item_scene: PackedScene
@export var drop_chance: float = 1.0 # 100% drop on kill

@export_group("AI Radii")
@export var detection_radius: float = 7.5
@export var attack_radius: float = 1.6
@export var patrol_range: float = 4.0

@export_group("Attack Timings")
@export var windup_duration: float = 0.55
@export var recovery_duration: float = 0.65
@export var attack_cooldown: float = 1.8

@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hitbox_area: Area3D = $ClubHitboxArea3D
@onready var hurtbox_area: Area3D = $HurtboxArea3D
@onready var detection_area: Area3D = $DetectionArea3D
@onready var telegraph_cue: Node3D = $TelegraphCue

var current_state: State = State.IDLE
var current_health: float = 80.0
var target_player: Player = null
var facing_direction: float = -1.0
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var patrol_anchor_x: float = 0.0
var patrol_target_x: float = 0.0
var has_dropped_reward: bool = false


func _ready() -> void:
	current_health = max_health
	patrol_anchor_x = global_position.x
	_pick_new_patrol_target()
	
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	if hitbox_area and not hitbox_area.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)
		
	_set_hitbox_active(false)
	if telegraph_cue:
		telegraph_cue.visible = false
		
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK_WINDUP:
			_process_attack_windup(delta)
		State.ATTACK_SWING:
			_process_attack_swing(delta)
		State.RECOVERY:
			_process_recovery(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	move_and_slide()
	_update_facing_and_sprite()


func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	
	if _find_player_in_range(detection_radius):
		_change_state(State.CHASE)
		return
		
	state_timer -= delta
	if state_timer <= 0.0:
		_pick_new_patrol_target()
		_change_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	if _find_player_in_range(detection_radius):
		_change_state(State.CHASE)
		return
		
	var diff_x = patrol_target_x - global_position.x
	if abs(diff_x) < 0.2:
		_change_state(State.IDLE)
		return
		
	facing_direction = sign(diff_x)
	velocity.x = facing_direction * patrol_speed
	velocity.z = 0.0


func _process_chase(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = null
		_change_state(State.IDLE)
		return
		
	var to_player = target_player.global_position - global_position
	var dist_sq = to_player.length_squared()
	
	if dist_sq > detection_radius * detection_radius * 1.5:
		target_player = null
		_change_state(State.IDLE)
		return
		
	if dist_sq <= attack_radius * attack_radius:
		if cooldown_timer <= 0.0:
			_change_state(State.ATTACK_WINDUP)
			return
		else:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			return
			
	var move_dir = Vector3(to_player.x, 0, to_player.z).normalized()
	facing_direction = sign(to_player.x) if abs(to_player.x) > 0.1 else facing_direction
	velocity.x = move_dir.x * chase_speed
	velocity.z = move_dir.z * (chase_speed * 0.7)


func _process_attack_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.ATTACK_SWING)


func _process_attack_swing(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)


func _process_recovery(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	state_timer -= delta
	if state_timer <= 0.0:
		_change_state(State.CHASE if is_instance_valid(target_player) else State.IDLE)


func _process_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)


func _change_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.IDLE:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			state_timer = randf_range(1.0, 2.5)
			animated_sprite.play("idle")

		State.PATROL:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			animated_sprite.play("walk")

		State.CHASE:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			animated_sprite.play("run")

		State.ATTACK_WINDUP:
			_set_hitbox_active(false)
			state_timer = windup_duration
			if telegraph_cue: telegraph_cue.visible = true
			animated_sprite.play("attack_windup")

		State.ATTACK_SWING:
			if telegraph_cue: telegraph_cue.visible = false
			_set_hitbox_active(true)
			velocity.x = facing_direction * 2.0
			animated_sprite.play("attack_swing")

		State.RECOVERY:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			cooldown_timer = attack_cooldown
			state_timer = recovery_duration
			animated_sprite.play("idle")

		State.HURT:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			animated_sprite.play("hurt")

		State.DEAD:
			_set_hitbox_active(false)
			if telegraph_cue: telegraph_cue.visible = false
			animated_sprite.play("dead")
			rotation_degrees.x = -85.0
			scale = Vector3(1.45, 0.35, 1.35)
			collision_shape.set_deferred("disabled", true)
			_drop_healing_reward()
			enemy_died.emit()


func _drop_healing_reward() -> void:
	if has_dropped_reward or not drop_item_scene:
		return
	has_dropped_reward = true
	
	if randf() <= drop_chance:
		var drop = drop_item_scene.instantiate() as Node3D
		drop.global_position = global_position + Vector3(0, 0.5, 0)
		get_parent().add_child(drop)


func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK_SWING:
			_change_state(State.RECOVERY)
		State.HURT:
			_change_state(State.CHASE if is_instance_valid(target_player) else State.IDLE)


func _set_hitbox_active(is_active: bool) -> void:
	if hitbox_area:
		hitbox_area.monitoring = is_active
		hitbox_area.monitorable = is_active


func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent() as Player
		if player_node:
			var knock_dir = Vector3(facing_direction, 0.4, 0).normalized()
			player_node.take_damage(attack_damage, knock_dir)


func take_damage(amount: float, is_electro: bool = true, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return
		
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	enemy_damaged.emit(amount, is_electro)
	
	velocity = knockback_dir * knockback_force
	velocity.y = 2.0
	
	if current_health <= 0.0:
		_change_state(State.DEAD)
	else:
		_change_state(State.HURT)


func _find_player_in_range(radius: float) -> bool:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Player and p.current_state != Player.State.DEAD:
			var dist_sq = global_position.distance_squared_to(p.global_position)
			if dist_sq <= radius * radius:
				target_player = p
				return true
	return false


func _pick_new_patrol_target() -> void:
	patrol_target_x = patrol_anchor_x + randf_range(-patrol_range, patrol_range)


func _update_facing_and_sprite() -> void:
	if facing_direction < 0.0:
		animated_sprite.flip_h = false
		if hitbox_area:
			hitbox_area.position.x = -abs(hitbox_area.position.x)
	else:
		animated_sprite.flip_h = true
		if hitbox_area:
			hitbox_area.position.x = abs(hitbox_area.position.x)
