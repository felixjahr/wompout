extends Control


@onready var create_button := $CenterContainer/VBoxContainer/CenterContainer/VBoxContainer/Create
@onready var join_button := $CenterContainer/VBoxContainer/CenterContainer/VBoxContainer/Join
@onready var options_button := $CenterContainer/VBoxContainer/CenterContainer/VBoxContainer/Options
@onready var name_label := $CenterContainer/VBoxContainer/VBoxContainer/Name
@onready var version_label := $Version


func _ready() -> void:
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version")
