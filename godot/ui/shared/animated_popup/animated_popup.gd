class_name AnimatedPopup
extends Control

var popup_tween: Tween

@onready var visual: Control = get_child(0)


func animate_popup(opening: bool) -> void:
	if popup_tween:
		popup_tween.kill()

	if opening:
		if not visible:
			visual.scale = Vector2.ONE * 0.01
		show()

	visual.pivot_offset = visual.size / 2.0

	popup_tween = create_tween()
	popup_tween.set_trans(
		Tween.TRANS_BACK if opening else Tween.TRANS_CUBIC
	)
	popup_tween.set_ease(
		Tween.EASE_OUT if opening else Tween.EASE_IN
	)
	popup_tween.tween_property(
		visual,
		"scale",
		Vector2.ONE if opening else Vector2.ONE * 0.01,
		0.35 if opening else 0.25
	)

	if not opening:
		popup_tween.tween_callback(hide)
