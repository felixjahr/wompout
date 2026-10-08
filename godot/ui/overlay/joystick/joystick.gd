extends Control
class_name Joystick

signal released(direction: Vector2)

const DEADZONE_SIZE: float = 10
const CLAMPZONE_SIZE: float = 120

@export var tip_pressed: Texture2D

var output := Vector2.ZERO
var deadzone_exited := false
var is_outside_deadzone := false
var active_touch_index := -1
var is_active := false

@onready var base := $CanvasGroup/Base
@onready var tip := $CanvasGroup/Base/Tip
@onready var tip_normal: Texture = tip.texture
@onready var default_base_position: Vector2 = base.position
@onready var default_tip_position: Vector2 = tip.position


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_activate_touch(event.index, event.position)
		else:
			_release_touch(event.index, event.position)
	elif event is InputEventScreenDrag and event.index == active_touch_index:
		_update_output(event.position)
		get_viewport().set_input_as_handled()


func _activate_touch(touch_index: int, touch_position: Vector2) -> void:
	if active_touch_index != -1 or not get_global_rect().has_point(touch_position):
		return
	base.global_position = touch_position - base.size / 2
	active_touch_index = touch_index
	tip.texture = tip_pressed
	is_active = true
	_update_output(touch_position)
	get_viewport().set_input_as_handled()


func _release_touch(touch_index: int, touch_position: Vector2) -> void:
	if touch_index != active_touch_index:
		return
	_update_output(touch_position)
	if not deadzone_exited:
		released.emit(Vector2.ZERO)
	elif is_outside_deadzone:
		released.emit(output)
	_reset_touch()
	get_viewport().set_input_as_handled()


func _update_output(touch_position: Vector2) -> void:
	var center: Vector2 = base.global_position + base.size / 2
	var vector: Vector2 = touch_position - center
	vector = vector.limit_length(CLAMPZONE_SIZE)
	tip.global_position = center + vector - tip.size / 2
	if vector.length_squared() > DEADZONE_SIZE * DEADZONE_SIZE:
		deadzone_exited = true
		is_outside_deadzone = true
		output = vector.normalized()
	else:
		if is_outside_deadzone:
			Input.vibrate_handheld(30)
		is_outside_deadzone = false
		output = Vector2.ZERO


func _reset_touch():
	deadzone_exited = false
	is_outside_deadzone = false
	output = Vector2.ZERO
	active_touch_index = -1
	tip.texture = tip_normal
	is_active = false
	base.position = default_base_position
	tip.position = default_tip_position
