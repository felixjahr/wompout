extends CenterContainer

signal create_guest_requested(displayName: String)
signal back_pressed

@onready var name_line_edit := %NameLineEdit


func show_guest() -> void:
	name_line_edit.text = ""
	show()


func _on_guest_button_pressed() -> void:
	create_guest_requested.emit(name_line_edit.text)


func _on_back_button_pressed() -> void:
	back_pressed.emit()
