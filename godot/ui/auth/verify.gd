extends CenterContainer

signal code_entered(code: String)
signal back_pressed

@onready var code_line_edit := %CodeLineEdit


func show_verify() -> void:
	code_line_edit.text = ""
	show()


func _on_code_line_edit_text_changed(new_text: String) -> void:
	if new_text.length() != 6:
		return
	code_entered.emit(code_line_edit.text)


func _on_back_button_pressed() -> void:
	back_pressed.emit()
