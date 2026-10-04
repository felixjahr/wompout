extends Node2D

<<<<<<< HEAD
=======

>>>>>>> origin/main
@onready var camera := $Camera2D
@onready var arena := $Arena
@onready var collision_shapes := [
	$CollisionPolygon2D,
	$CollisionPolygon2D2,
]
@onready var spawn_points := [
	$SpawnPoints/Marker2D,
<<<<<<< HEAD
	$SpawnPoints/Marker2D2,
	$SpawnPoints/Marker2D3,
	$SpawnPoints/Marker2D4,
=======
	$SpawnPoints/Marker2D2
>>>>>>> origin/main
]


func _ready() -> void:
<<<<<<< HEAD
	if not OS.has_feature("dedicated_server"):
=======
	if not OS.has_feature("server"):
>>>>>>> origin/main
		arena.queue_free()
