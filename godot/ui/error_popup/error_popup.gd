extends Control

var error_tween: Tween

@onready var visual := %Visual
@onready var error_label := %ErrorLabel


func _ready() -> void:
	hide()


func show_error(message: String) -> void:
	error_label.text = message
	_animate_error(true)


func _animate_error(opening: bool) -> void:
	if error_tween:
		error_tween.kill()

	if opening:
		if not visible:
			visual.scale = Vector2.ONE * 0.01
		show()

	visual.pivot_offset = visual.size / 2.0

	error_tween = create_tween()
	error_tween.set_trans(
		Tween.TRANS_BACK if opening else Tween.TRANS_CUBIC
	)
	error_tween.set_ease(
		Tween.EASE_OUT if opening else Tween.EASE_IN
	)
	error_tween.tween_property(
		visual,
		"scale",
		Vector2.ONE if opening else Vector2.ONE * 0.01,
		0.35 if opening else 0.25
	)

	if not opening:
		error_tween.tween_callback(hide)


func _on_ok_button_pressed() -> void:
	_animate_error(false)


func _on_close_button_pressed() -> void:
	_animate_error(false)
