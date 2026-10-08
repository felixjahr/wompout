extends Node2D

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
	$SpawnPoints/Marker2D2,
	$SpawnPoints/Marker2D3,
	$SpawnPoints/Marker2D4,
]


func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		for collision_shape in collision_shapes:
			arena.queue_free()
