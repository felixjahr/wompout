class_name Bullet
extends Projectile


func get_client_scene() -> PackedScene:
	return preload("res://projectile/bullet/bullet_client.tscn")


func get_server_scene() -> PackedScene:
	return preload("res://projectile/bullet/bullet_server.tscn")
