extends Node2D

var speed: int
var damage: int
var friendly_fire: bool
var range: int

var direction: Vector2
var participant_id: String
var bullet_id: String

@onready var hitbox := $Hitbox
@onready var arena := $Arena
@onready var start_position := global_position
@onready var logic := get_parent().get_parent()


func _ready() -> void:
	rotation = direction.angle()


func tick(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) >= range:
		logic.despawn_bullet(bullet_id)


func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if not logic.can_hit(participant_id, target.participant_id, friendly_fire):
		return
	target.apply_hit(damage, participant_id)
	logic.despawn_bullet(bullet_id)


func _on_hitbox_body_entered(body: Node2D) -> void:
	logic.despawn_bullet(bullet_id)


func _on_arena_area_exited(area: Area2D) -> void:
	logic.despawn_bullet(bullet_id)
