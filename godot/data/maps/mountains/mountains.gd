extends Node2D

<<<<<<< HEAD
=======

>>>>>>> origin/main
@onready var camera := $Camera2D
@onready var arena := $Arena
@onready var collision_shapes := [
	$CollisionShape2D,
	$CollisionShape2D2,
	$CollisionShape2D3,
	$CollisionShape2D4,
	$CollisionShape2D5,
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
		for collision_shape in collision_shapes:
			arena.queue_free()
