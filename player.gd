## player.gd - Production-Ready Raiden Shogun Controller (Godot 4.3+)
## Tailored for 2.5D / 3D Mobile Action Games.
class_name Player
extends CharacterBody3D

# --- Signals ---
signal health_changed(current_hp: float, max_hp: float)
signal burst_energy_changed(current_energy: float, max_energy: float)
signal resolve_stacks_changed(stacks: int, max_stacks: int)
signal state_changed(new_state_name: String)
signal player_healed(amount: float)
signal player_died

# --- State Machine Enum ---
enum State {
	IDLE,
	RUN,
	JUMP,
	DASH,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	SKILL,
	BURST,
	HURT,
	DEAD
}

# --- Exported Parameters ---
@export_group("Movement & Physics")
@export var move_speed: float = 7.0
@export var acceleration: float = 28.0
@export var friction: float = 35.0
@export var jump_velocity: float = 11.5
@export var dash_speed: float = 14.0
@export var dash_duration: float = 0.25
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

@export_group("Combat Stats")
@export var max_health: float = 100.0
@export var max_burst_energy: float = 80.0
@export var max_resolve_stacks: int = 60
@export var attack_damage_1: float = 15.0
@export var attack_damage_2: float = 22.0
@export var attack_damage_3: float = 38.0
@export var skill_damage: float = 45.0
@export var burst_damage: float = 120.0
@export var skill_cooldown_time: float = 8.0

@export_group("Combo Window")
@export var combo_buffer_time: float = 0.4

# --- Node References ---
@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hitbox_area: Area3D = $HitboxPivot/HitboxArea3D
@onready var hurtbox_area: Area3D = $HurtboxArea3D
@onready var eye_of_stormy_judgment: Node3D = $EyeOfStormyJudgmentPivot/EyeEffect

# --- Particle Nodes ---
@onready var skill_particles: GPUParticles3D = $VFX/SkillParticles
@onready var dash_particles: GPUParticles3D = $VFX/DashParticles
@onready var jump_particles: GPUParticles3D = $VFX/JumpParticles
@onready var heal_particles: GPUParticles3D = $VFX/HealParticles

# --- Internal State ---
var current_state: State = State.IDLE
var current_health: float = 100.0
var burst_energy: float = 80.0
var resolve_stacks: int = 0
var skill_cooldown_timer: float = 0.0

var mobile_input_vector: Vector2 = Vector2.ZERO
var combo_buffered: bool = false
var can_combo_window_open: bool = false
var dash_timer: float = 0.0
var is_invincible: bool = false
var facing_direction: float = 1.0
var was_on_floor_last_frame: bool = true

var is_eye_buff_active: bool = false
var eye_buff_duration: float = 0.0

func _ready() -> void:
	current_health = max_health
	burst_energy = max_burst_energy
	
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_3d_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_3d_animation_finished)
	
	_set_hitbox_active(false)
	
	if eye_of_stormy_judgment:
		eye_of_stormy_judgment.visible = false
		
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if skill_cooldown_timer > 0.0:
		skill_cooldown_timer = max(0.0, skill_cooldown_timer - delta)
		
	if is_eye_buff_active:
		eye_buff_duration -= delta
		if eye_buff_duration <= 0.0:
			is_eye_buff_active = false
			if eye_of_stormy_judgment:
				eye_of_stormy_judgment.visible = false

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		if not was_on_floor_last_frame and jump_particles:
			jump_particles.restart()
			jump_particles.emitting = true

	was_on_floor_last_frame = is_on_floor()

	match current_state:
		State.IDLE, State.RUN, State.JUMP:
			_process_movement_state(delta)
		State.DASH:
			_process_dash_state(delta)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, State.SKILL, State.BURST:
			_process_attack_state(delta)
		State.HURT:
			_process_hurt_state(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()
	_update_sprite_orientation()


# ==============================================================================
# HEALING & RESOURCE RECOVERY (Called when picking up Inazuma item drops)
# ==============================================================================

## Restores player HP from dropped Inazuma items (e.g. Naku Weed, Healing Orbs)
func heal(amount: float) -> void:
	if current_state == State.DEAD:
		return
		
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	player_healed.emit(amount)
	
	# Trigger Green Healing Sparkles VFX
	if heal_particles:
		heal_particles.restart()
		heal_particles.emitting = true


func set_mobile_input_vector(input_vec: Vector2) -> void:
	mobile_input_vector = input_vec.limit_length(1.0)


func _get_desired_movement_vector() -> Vector2:
	if mobile_input_vector.length_squared() > 0.01:
		return mobile_input_vector
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func on_jump_pressed() -> void:
	if current_state in [State.DEAD, State.BURST, State.HURT]:
		return
	if is_on_floor():
		velocity.y = jump_velocity
		if jump_particles:
			jump_particles.restart()
			jump_particles.emitting = true
		_change_state(State.JUMP)


func on_attack_pressed() -> void:
	if current_state == State.DEAD:
		return

	match current_state:
		State.IDLE, State.RUN, State.JUMP:
			_execute_attack_step(1)
		State.ATTACK_1, State.ATTACK_2:
			combo_buffered = true
		State.ATTACK_3:
			combo_buffered = true


func on_skill_pressed() -> void:
	if current_state in [State.DEAD, State.BURST, State.HURT]:
		return
	if skill_cooldown_timer > 0.0:
		return
		
	skill_cooldown_timer = skill_cooldown_time
	if skill_particles:
		skill_particles.restart()
		skill_particles.emitting = true
	_change_state(State.SKILL)


func on_burst_pressed() -> void:
	if current_state in [State.DEAD, State.BURST, State.HURT]:
		return
	if burst_energy < max_burst_energy:
		return
		
	burst_energy = 0.0
	burst_energy_changed.emit(burst_energy, max_burst_energy)
	_change_state(State.BURST)


func on_dash_pressed() -> void:
	if current_state in [State.DEAD, State.BURST]:
		return
	if dash_particles:
		dash_particles.restart()
		dash_particles.emitting = true
	_change_state(State.DASH)


func _change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(State.keys()[new_state])
	
	match new_state:
		State.IDLE:
			_set_hitbox_active(false)
			combo_buffered = false
			can_combo_window_open = false
			animated_sprite.play("idle")

		State.RUN:
			_set_hitbox_active(false)
			combo_buffered = false
			can_combo_window_open = false
			animated_sprite.play("run")

		State.JUMP:
			_set_hitbox_active(false)
			animated_sprite.play("idle")

		State.DASH:
			dash_timer = dash_duration
			is_invincible = true
			_set_hitbox_active(false)
			var input_vec = _get_desired_movement_vector()
			var dash_dir = Vector3(input_vec.x, 0, input_vec.y)
			if dash_dir.length_squared() < 0.01:
				dash_dir = Vector3(facing_direction, 0, 0)
			else:
				dash_dir = dash_dir.normalized()
			velocity.x = dash_dir.x * dash_speed
			velocity.z = dash_dir.z * dash_speed
			animated_sprite.play("dash")

		State.ATTACK_1:
			_setup_attack_step(attack_damage_1, "attack1", 2.0)

		State.ATTACK_2:
			_setup_attack_step(attack_damage_2, "attack2", 3.0)

		State.ATTACK_3:
			_setup_attack_step(attack_damage_3, "attack3", 5.0)

		State.SKILL:
			combo_buffered = false
			_set_hitbox_active(true, skill_damage, true)
			velocity.x = facing_direction * 2.5
			velocity.z = 0.0
			is_eye_buff_active = true
			eye_buff_duration = 20.0
			if eye_of_stormy_judgment:
				eye_of_stormy_judgment.visible = true
			animated_sprite.play("skill")

		State.BURST:
			combo_buffered = false
			is_invincible = true
			_set_hitbox_active(true, burst_damage, true)
			velocity = Vector3.ZERO
			resolve_stacks = 0
			resolve_stacks_changed.emit(resolve_stacks, max_resolve_stacks)
			animated_sprite.play("burst")

		State.HURT:
			_set_hitbox_active(false)
			combo_buffered = false
			animated_sprite.play("hurt")

		State.DEAD:
			_set_hitbox_active(false)
			if hurtbox_area:
				hurtbox_area.set_deferred("monitoring", false)
				hurtbox_area.set_deferred("monitorable", false)
			animated_sprite.play("dead")
			# Lay flat on the 3D ground plane horizontally with comical pancake squash
			var tween = create_tween().set_parallel(true)
			tween.tween_property(animated_sprite, "rotation:x", deg_to_rad(-85.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(animated_sprite, "position:y", 0.16, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(animated_sprite, "scale", Vector3(1.35, 0.4, 1.3), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			player_died.emit()


func _setup_attack_step(dmg: float, anim_name: String, forward_step: float) -> void:
	combo_buffered = false
	can_combo_window_open = true
	_set_hitbox_active(true, dmg, true)
	velocity.x = facing_direction * forward_step
	velocity.z = 0.0
	animated_sprite.play(anim_name)


func _execute_attack_step(step: int) -> void:
	match step:
		1: _change_state(State.ATTACK_1)
		2: _change_state(State.ATTACK_2)
		3: _change_state(State.ATTACK_3)


func _on_animated_sprite_3d_animation_finished() -> void:
	match current_state:
		State.ATTACK_1:
			if combo_buffered:
				_execute_attack_step(2)
			else:
				_return_to_locomotion()

		State.ATTACK_2:
			if combo_buffered:
				_execute_attack_step(3)
			else:
				_return_to_locomotion()

		State.ATTACK_3:
			combo_buffered = false
			_return_to_locomotion()

		State.SKILL, State.BURST, State.DASH, State.HURT:
			is_invincible = false
			_set_hitbox_active(false)
			_return_to_locomotion()


func _return_to_locomotion() -> void:
	if not is_on_floor():
		_change_state(State.JUMP)
		return
		
	var move_vec = _get_desired_movement_vector()
	if move_vec.length_squared() > 0.01:
		_change_state(State.RUN)
	else:
		_change_state(State.IDLE)


func _process_movement_state(delta: float) -> void:
	var input_vec = _get_desired_movement_vector()
	
	if input_vec.length_squared() > 0.01:
		if abs(input_vec.x) > 0.1:
			facing_direction = sign(input_vec.x)

		var target_vx = input_vec.x * move_speed
		var target_vz = input_vec.y * (move_speed * 0.7)
		
		velocity.x = move_toward(velocity.x, target_vx, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vz, acceleration * delta)
		
		if is_on_floor() and current_state != State.RUN:
			_change_state(State.RUN)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		
		if is_on_floor() and current_state != State.IDLE:
			_change_state(State.IDLE)


func _process_dash_state(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0.0:
		is_invincible = false
		_return_to_locomotion()


func _process_attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 1.5 * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * 1.5 * delta)


func _process_hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _update_sprite_orientation() -> void:
	if facing_direction < 0.0:
		animated_sprite.flip_h = true
		if hitbox_area:
			hitbox_area.position.x = -abs(hitbox_area.position.x)
	else:
		animated_sprite.flip_h = false
		if hitbox_area:
			hitbox_area.position.x = abs(hitbox_area.position.x)


func _set_hitbox_active(is_active: bool, dmg: float = 0.0, is_electro: bool = true) -> void:
	if hitbox_area:
		hitbox_area.monitoring = is_active
		hitbox_area.monitorable = is_active
		if hitbox_area.has_method("set_damage_properties"):
			hitbox_area.set_damage_properties(dmg, is_electro)


func take_damage(amount: float, knockback_vector: Vector3) -> void:
	if is_invincible or current_state == State.DEAD:
		return

	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	velocity.x = knockback_vector.x * 6.0
	velocity.z = knockback_vector.z * 6.0
	velocity.y = 3.0
	
	if current_health <= 0.0:
		_change_state(State.DEAD)
	else:
		_change_state(State.HURT)


func respawn() -> void:
	current_health = max_health
	burst_energy = max_burst_energy
	resolve_stacks = max_resolve_stacks
	is_invincible = false
	if hurtbox_area:
		hurtbox_area.set_deferred("monitoring", true)
		hurtbox_area.set_deferred("monitorable", true)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(animated_sprite, "rotation:x", 0.0, 0.25)
	tween.tween_property(animated_sprite, "position:y", 1.0, 0.25)
	tween.tween_property(animated_sprite, "scale", Vector3.ONE, 0.25)
	health_changed.emit(current_health, max_health)
	burst_energy_changed.emit(burst_energy, max_burst_energy)
	_change_state(State.IDLE)
