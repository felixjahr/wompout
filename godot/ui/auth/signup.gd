extends CenterContainer

signal start_signup_requested(displayName: String, email: String)
signal login_pressed
signal guest_pressed

@onready var name_line_edit := %NameLineEdit
@onready var email_line_edit := %EmailLineEdit


func show_signup() -> void:
	name_line_edit.text = ""
	email_line_edit.text = ""
	show()


func _on_signup_button_pressed() -> void:
	start_signup_requested.emit(name_line_edit.text, email_line_edit.text)


func _on_login_button_pressed() -> void:
	login_pressed.emit()


func _on_guest_button_pressed() -> void:
	guest_pressed.emit()
