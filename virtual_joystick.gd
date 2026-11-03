## virtual_joystick.gd - Mobile Touch Joystick for Godot 4.3+
class_name VirtualJoystick
extends Control

signal analog_changed(vector: Vector2)
signal analog_released

@export var max_radius: float = 65.0
@export var deadzone: float = 0.12
@export var return_speed: float = 24.0

@onready var base_ring: TextureRect = $BaseRing
@onready var thumb_knob: TextureRect = $ThumbKnob

var touch_index: int = -1
var analog_vector: Vector2 = Vector2.ZERO
var knob_home_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	knob_home_position = thumb_knob.position


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			var local_pos = event.position - global_position
			if local_pos.length() <= max_radius * 1.5:
				touch_index = event.index
				_process_drag(local_pos)
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()

	elif event is InputEventScreenDrag and event.index == touch_index:
		var local_pos = event.position - global_position
		_process_drag(local_pos)


func _process(delta: float) -> void:
	if touch_index == -1 and thumb_knob.position != knob_home_position:
		thumb_knob.position = thumb_knob.position.lerp(knob_home_position, return_speed * delta)


func _process_drag(local_pos: Vector2) -> void:
	var offset = local_pos - knob_home_position
	var length = offset.length()
	
	if length > max_radius:
		offset = offset.normalized() * max_radius
		
	thumb_knob.position = knob_home_position + offset
	
	var normalized_vec = offset / max_radius
	if normalized_vec.length() < deadzone:
		analog_vector = Vector2.ZERO
	else:
		analog_vector = normalized_vec
		
	analog_changed.emit(analog_vector)


func _reset_joystick() -> void:
	touch_index = -1
	analog_vector = Vector2.ZERO
	analog_changed.emit(Vector2.ZERO)
	analog_released.emit()
