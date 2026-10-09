extends AnimatedPopup

@onready var error_label := %ErrorLabel


func _ready() -> void:
	hide()


func show_error(message: String) -> void:
	error_label.text = message
	animate_popup(true)


func _on_ok_button_pressed() -> void:
	animate_popup(false)


func _on_close_button_pressed() -> void:
	animate_popup(false)
