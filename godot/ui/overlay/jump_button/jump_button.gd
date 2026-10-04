extends Control

signal pressed

@export var texture_pressed: Texture2D

var active_touch_index := -1

@onready var texture := $CanvasGroup/Texture
@onready var texture_normal: Texture = texture.texture


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_activate_touch(event.index, event.position)
		else:
			_release_touch(event.index)


func _activate_touch(touch_index: int, touch_position: Vector2) -> void:
	if active_touch_index != -1 or not get_global_rect().has_point(touch_position):
		return
	active_touch_index = touch_index
	texture.texture = texture_pressed
	pressed.emit()
	get_viewport().set_input_as_handled()


func _release_touch(touch_index: int) -> void:
	if touch_index != active_touch_index:
		return
	_reset_touch()
	get_viewport().set_input_as_handled()


func _reset_touch():
	active_touch_index = -1
	texture.texture = texture_normal
