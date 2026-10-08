extends Node2D

@onready var camera := $Camera2D
@onready var arena := $Arena
@onready var collision_shapes := [
	$CollisionPolygon2D,
	$CollisionPolygon2D2,
]
@onready var spawn_points := [
	$SpawnPoints/Marker2D,
	$SpawnPoints/Marker2D2,
	$SpawnPoints/Marker2D3,
	$SpawnPoints/Marker2D4,
]


func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		arena.queue_free()
