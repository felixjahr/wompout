class_name ProjectileClient
extends Node2D

var projectile: Projectile

@onready var sprite := $Sprite2D


func _ready() -> void:
	sprite.texture = projectile.texture


func apply_snapshot(snapshot: BulletSnapshot) -> void:
	rotation = snapshot.direction.angle()
	global_position = snapshot.position
