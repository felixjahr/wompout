extends StaticBody2D

@export var damage := 10


@onready var hitbox := $Hitbox
@onready var collision_shape := $CollisionShape2D
@onready var hitbox_collision_shape := $Hitbox/CollisionShape2D


func _ready() -> void:
	if not OS.has_feature("server"):
		collision_shape.queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	area.get_parent().apply_hit(damage)
	hitbox_collision_shape.set_deferred("disabled", true)
	await get_tree().create_timer(0.2).timeout
	hitbox_collision_shape.set_deferred("disabled", false)
