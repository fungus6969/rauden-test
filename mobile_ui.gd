## mobile_ui.gd - Mobile In-Game HUD & Touch Controls (Godot 4.3+)
class_name MobileCombatUI
extends CanvasLayer

@export var player_node: Player

@onready var virtual_joystick: VirtualJoystick = $LeftTouchZone/VirtualJoystick
@onready var jump_btn: TouchScreenButton = $RightActions/JumpButton
@onready var attack_btn: TouchScreenButton = $RightActions/AttackButton
@onready var skill_btn: TouchScreenButton = $RightActions/SkillButton
@onready var burst_btn: TouchScreenButton = $RightActions/BurstButton
@onready var dash_btn: TouchScreenButton = $RightActions/DashButton

@onready var hp_bar: ProgressBar = $TopBars/HealthBar
@onready var burst_fill: TextureProgressBar = $RightActions/BurstButton/EnergyProgress
@onready var skill_cooldown_label: Label = $RightActions/SkillButton/CooldownLabel


func _ready() -> void:
	if not player_node:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0] as Player

	if player_node:
		player_node.health_changed.connect(_on_player_health_changed)
		player_node.burst_energy_changed.connect(_on_burst_energy_changed)

	if virtual_joystick:
		virtual_joystick.analog_changed.connect(_on_joystick_vector_changed)

	if jump_btn:
		jump_btn.pressed.connect(_on_jump_pressed)
	if attack_btn:
		attack_btn.pressed.connect(_on_attack_pressed)
	if skill_btn:
		skill_btn.pressed.connect(_on_skill_pressed)
	if burst_btn:
		burst_btn.pressed.connect(_on_burst_pressed)
	if dash_btn:
		dash_btn.pressed.connect(_on_dash_pressed)


func _on_joystick_vector_changed(vec: Vector2) -> void:
	if is_instance_valid(player_node):
		player_node.set_mobile_input_vector(vec)


func _on_jump_pressed() -> void:
	if is_instance_valid(player_node):
		player_node.on_jump_pressed()


func _on_attack_pressed() -> void:
	if is_instance_valid(player_node):
		player_node.on_attack_pressed()


func _on_skill_pressed() -> void:
	if is_instance_valid(player_node):
		player_node.on_skill_pressed()


func _on_burst_pressed() -> void:
	if is_instance_valid(player_node):
		player_node.on_burst_pressed()


func _on_dash_pressed() -> void:
	if is_instance_valid(player_node):
		player_node.on_dash_pressed()


func _on_player_health_changed(hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp


func _on_burst_energy_changed(energy: float, max_energy: float) -> void:
	if burst_fill:
		burst_fill.max_value = max_energy
		burst_fill.value = energy
