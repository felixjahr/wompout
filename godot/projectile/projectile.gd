@abstract
class_name Projectile
extends Resource

@export var speed: int
@export var range: int
@export var damage: int
@export var knockback: int
@export var friendly_fire: bool
@export var texture: Texture2D


@abstract
func get_client_scene() -> PackedScene


@abstract
func get_server_scene() -> PackedScene
