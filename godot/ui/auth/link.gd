extends CenterContainer

signal start_link_requested(email: String)
signal back_pressed

@onready var email_line_edit := %EmailLineEdit


func show_link() -> void:
	email_line_edit.text = ""
	show()


func _on_link_button_pressed() -> void:
	start_link_requested.emit(email_line_edit.text)


func _on_back_button_pressed() -> void:
	back_pressed.emit()
