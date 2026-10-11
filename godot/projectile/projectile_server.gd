class_name ProjectileServer
extends Node2D

var projectile: Projectile
var projectile_id: String
var owner_id: String
var direction: Vector2
var weapon_id: String

@onready var hitbox := $Hitbox
@onready var arena := $Arena
@onready var start_position := global_position
@onready var logic := get_parent().get_parent()


func _ready() -> void:
	rotation = direction.angle()


func tick(delta: float) -> void:
	global_position += direction * projectile.speed * delta
	if global_position.distance_to(start_position) >= projectile.range:
		logic.despawn_bullet(projectile_id)


func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if not logic.can_hit(owner_id, target.participant_id, projectile.friendly_fire):
		return
	target.apply_hit(projectile.damage, owner_id, projectile.effect_id, global_position)
	target.apply_knockback(global_position, projectile.knockback)
	logic.despawn_bullet(projectile_id)


func _on_hitbox_body_entered(body: Node2D) -> void:
	logic.despawn_bullet(projectile_id)


func _on_arena_area_exited(area: Area2D) -> void:
	logic.despawn_bullet(projectile_id)
