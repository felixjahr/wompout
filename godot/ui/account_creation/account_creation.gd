extends Control

<<<<<<< HEAD
signal confirm_pressed(displayName: String)


@onready var name_edit := $CenterContainer/VBoxContainer/HBoxContainer/Name
@onready var confirm_button := $CenterContainer/VBoxContainer/Confirm


func _on_confirm_pressed() -> void:
	confirm_pressed.emit(name_edit.text)
=======

@onready var name_edit := $CenterContainer/VBoxContainer/HBoxContainer/Name
@onready var confirm_button := $CenterContainer/VBoxContainer/Confirm
>>>>>>> origin/main
