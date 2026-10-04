extends Control

signal pressed

const TEXTURE_ABILITY := {
	"dash" : preload("res://ui/overlay/ability_button/ability_dash.png"),
	"invisibility" : preload("res://ui/overlay/ability_button/ability_invisibility.png"),
}

const TEXTURE_ABILITY_READY := {
	"dash" : preload("res://ui/overlay/ability_button/ability_dash_ready.png"),
	"invisibility" : preload("res://ui/overlay/ability_button/ability_invisibility_ready.png"),
}

const TEXTURE := preload("res://ui/overlay/ability_button/ability_button.png")
const TEXTURE_READY := preload("res://ui/overlay/ability_button/ability_button_ready.png")
const TEXTURE_PRESSED := preload("res://ui/overlay/ability_button/ability_button_pressed.png")

var active_touch_index := -1
var disabled := false
var ability_id := ""

@onready var texture := $CanvasGroup/Texture


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_activate_touch(event.index, event.position)
		else:
			_release_touch(event.index)


func set_ability(ability_id: String) -> void:
	self.ability_id = ability_id


func set_texture_value(value: float) -> void:
	disabled = value < 100.0
	texture.value = 0
	if active_touch_index == -1:
		if disabled:
			texture.value = value
			texture.texture_under = TEXTURE
			texture.texture_over = TEXTURE_ABILITY[ability_id]
		else:
			texture.texture_under = TEXTURE_READY
			texture.texture_over = TEXTURE_ABILITY_READY[ability_id]


func _activate_touch(touch_index: int, touch_position: Vector2) -> void:
	if disabled or active_touch_index != -1 or not get_global_rect().has_point(touch_position):
		return
	active_touch_index = touch_index
	texture.texture_under = TEXTURE_PRESSED
	pressed.emit()
	get_viewport().set_input_as_handled()


func _release_touch(touch_index: int) -> void:
	if touch_index != active_touch_index:
		return
	_reset_touch()
	get_viewport().set_input_as_handled()


func _reset_touch():
	active_touch_index = -1
