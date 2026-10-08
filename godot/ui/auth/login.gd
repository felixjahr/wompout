extends CenterContainer

signal start_login_requested(email: String)
signal signup_pressed
signal guest_pressed

@onready var email_line_edit := %EmailLineEdit


func show_login() -> void:
	email_line_edit.text = ""
	show()


func _on_login_button_pressed() -> void:
	start_login_requested.emit(email_line_edit.text)


func _on_signup_button_pressed() -> void:
	signup_pressed.emit()


func _on_guest_button_pressed() -> void:
	guest_pressed.emit()
