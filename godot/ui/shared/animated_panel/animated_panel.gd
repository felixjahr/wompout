class_name AnimatedPanel
extends Control

@export var side: Side
@export var auto_close: bool = true

var panel_tween: Tween


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if visible and auto_close:
		var local_mouse = get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local_mouse):
			animate_panel(false)


func animate_panel(opening: bool) -> void:
	if panel_tween:
		panel_tween.kill()

	var horizontal := side == SIDE_LEFT or side == SIDE_RIGHT
	var from_end := side == SIDE_RIGHT or side == SIDE_BOTTOM
	var axis := 0 if horizontal else 1
	var screen_size := get_viewport_rect().size[axis]
	var panel_size := size[axis]

	var closed_position := screen_size if from_end else -panel_size
	var open_position = (
		screen_size - panel_size
		if from_end
		else 0
	)

	if opening:
		if not visible:
			position[axis] = closed_position
		show()

	panel_tween = create_tween()
	panel_tween.set_trans(Tween.TRANS_BACK if opening else Tween.TRANS_CUBIC)
	panel_tween.set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	panel_tween.tween_property(
		self,
		"position:x" if horizontal else "position:y",
		open_position if opening else closed_position,
		0.35 if opening else 0.25
	)

	if not opening:
		panel_tween.tween_callback(hide)
