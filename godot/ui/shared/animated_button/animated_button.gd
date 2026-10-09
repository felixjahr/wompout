class_name AnimatedButton
extends Button

@export var amount := 0.95

var shrink_tween: Tween

@onready var visual: Control = get_child(0)


func _ready() -> void:
	visual.resized.connect(_update_pivot)
	button_down.connect(func(): _scale_visual(amount, 0.06))
	button_up.connect(func(): _scale_visual(1.0, 0.1))
	mouse_exited.connect(func(): _scale_visual(1.0, 0.1))
	_update_pivot()


func _update_pivot() -> void:
	visual.pivot_offset = visual.size / 2.0


func _scale_visual(amount: float, duration: float) -> void:
	if shrink_tween:
		shrink_tween.kill()

	shrink_tween = create_tween()
	shrink_tween.set_trans(Tween.TRANS_QUAD)
	shrink_tween.set_ease(Tween.EASE_OUT)
	shrink_tween.tween_property(
		visual, "scale", Vector2.ONE * amount, duration
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN and is_node_ready():
		_scale_visual(1.0, 0.1)
