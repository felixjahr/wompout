extends Control

const CLAMPZONE_SIZE: float = 195

@export var tip_pressed: Texture2D

var output := 0.0
var active_touch_index := -1

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
			_release_touch(event.index)
	elif event is InputEventScreenDrag and event.index == active_touch_index:
		_update_output(event.position)
		get_viewport().set_input_as_handled()


func _activate_touch(touch_index: int, touch_position: Vector2) -> void:
	if active_touch_index != -1 or not get_global_rect().has_point(touch_position):
		return
	base.global_position.y = touch_position.y - base.size.y / 2
	active_touch_index = touch_index
	tip.texture = tip_pressed
	_update_output(touch_position)
	get_viewport().set_input_as_handled()


func _release_touch(touch_index: int) -> void:
	if touch_index != active_touch_index:
		return
	_reset_touch()
	get_viewport().set_input_as_handled()


func _update_output(touch_position : Vector2) -> void:
	var center: Vector2 = base.global_position + base.size / 2
	var vector: Vector2 = touch_position - center
	vector.y = 0
	vector = vector.limit_length(CLAMPZONE_SIZE)
	tip.global_position = center + vector - tip.size / 2
	output = remap(vector.x, -CLAMPZONE_SIZE, CLAMPZONE_SIZE, -1.0, 1.0)


func _reset_touch():
	output = 0.0
	active_touch_index = -1
	tip.texture = tip_normal
	base.position = default_base_position
	tip.position = default_tip_position
