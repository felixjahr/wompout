extends Node2D


func apply_snapshot(snapshot: BulletSnapshot) -> void:
	rotation = snapshot.direction.angle()
	global_position = snapshot.position
