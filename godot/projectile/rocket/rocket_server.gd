extends ProjectileServer

var explode := false

@onready var explosion_area := $Explosion
@onready var explosion_collision_shape := $Explosion/CollisionShape2D


func _ready() -> void:
	super._ready()
	explosion_collision_shape.shape = explosion_collision_shape.shape.duplicate()
	explosion_collision_shape.shape.radius = projectile.explosion_radius


func _on_hitbox_area_entered(area: Area2D) -> void:
	_explode()


func _on_hitbox_body_entered(body: Node2D) -> void:
	_explode()


func _on_arena_area_exited(area: Area2D) -> void:
	_explode()


func _explode() -> void:
	if explode:
		return
	explode = true
	var event := ExplosionEventSnapshot.new()
	event.position = global_position
	event.radius = projectile.explosion_radius
	logic.report_event(event)
	
	for area in explosion_area.get_overlapping_areas():
		var target = area.get_parent()
		if not logic.can_hit(owner_id, target.participant_id, projectile.friendly_fire):
			continue
		target.apply_hit(projectile.damage, owner_id)
		target.apply_knockback(global_position, projectile.knockback)
	logic.despawn_bullet(projectile_id)
