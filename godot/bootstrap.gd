extends Node


func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		get_tree().call_deferred("change_scene_to_file", "res://server/server.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://client/client.tscn")
