class_name Rocket
extends Projectile

@export var explosion_radius: float


func get_client_scene() -> PackedScene:
	return preload("res://projectile/rocket/rocket_client.tscn")


func get_server_scene() -> PackedScene:
	return preload("res://projectile/rocket/rocket_server.tscn")
