extends CharacterBody2D

const SPEED := 500.0
const ACCELERATION := 1500.0
const FRICTION := 1200.0
const GRAVITY := 1500.0
const JUMP_FORCE := -1200.0
const JUMPING_GRACE := 0.3

var player_id: String
var health := 100
var hearts := 3
var facing := 1

var jumping_grace_time_left := JUMPING_GRACE
var dead := false

var current_weapon := 0
var attacking := false
var aim_direction := Vector2.ZERO

var melee_id: String
var melee_ammunition: int
var melee_recharge_time := 0.0

var ranged_id: String
var ranged_ammunition: int
var ranged_recharge_time := 0.0

var attack_time_left := 0.0
var burst_time_left := 0.0
var burst_bullet_amount: int

var ability_id: String
var ability_active := false
var last_ability := -1
var ability_charge: int
var ability_time_left := 0.0

var armour_id: String

@onready var logic := get_parent().get_parent()
@onready var pivot := $Pivot
@onready var hitbox_collision_shape := $Pivot/Hitbox/CollisionShape2D
@onready var slam_down_area := $SlamDown
@onready var slam_down_marker := $SlamDownMarker


func _ready() -> void:
	melee_ammunition = Data.MELEE[melee_id].max_ammunition
	ranged_ammunition = Data.RANGED[ranged_id].max_ammunition
	hitbox_collision_shape.set_deferred("disabled", true)


func tick(delta: float, input: PlayerInput) -> void:
	if dead:
		return
	
	_update_reload_times(delta)
	_update_attack_time(delta)
	_update_burst_time(delta)
	
	_apply_horizontal_movement(delta, input.direction)
	_apply_vertical_movement(delta, input.jumping)
	
	if input.ability and ability_charge >= Data.ABILITY[ability_id].charge:
		ability_charge = 0
		match ability_id:
			"double_jump":
				_ability_double_jump()
			"dash":
				_ability_dash(input.direction)
			"invisibility":
				_ability_invisibility()
			"slam_down":
				_ability_slam_down()
	
	if ability_active:
		match ability_id:
			"invisibility":
				_ability_update_invisibility(delta)
			"slam_down":
				_ability_update_slam_down(delta)
	
	if not attacking:
		aim_direction = input.aim_direction
		current_weapon = input.current_weapon
		if input.attacking:
			var has_ammunition := (
					current_weapon == 0 and melee_ammunition > 0
					or current_weapon == 1 and ranged_ammunition > 0
			)
			if has_ammunition:
				if aim_direction == Vector2.ZERO:
					aim_direction = _get_auto_aim_direction()
				if current_weapon == 0:
					attacking = true
					_start_melee_attack()
				elif current_weapon == 1:
					attacking = true
					_start_ranged_attack()
		else:
			_update_facing()
	
	move_and_slide()


func apply_knockback(position: Vector2, knockback: float) -> void:
	var knockback_multiplier := Data.ARMOUR[armour_id].knockback_multiplier
	velocity = position.direction_to(global_position) * knockback * knockback_multiplier


func apply_hit(damage: int, attacker_player_id := "", effect_id := "", effect_position := Vector2.ZERO) -> void:
	if dead:
		return
	var damage_multiplier := Data.ARMOUR[armour_id].damage_multiplier
	health -= damage * damage_multiplier
	var event := HitEventSnapshot.new()
	event.victim_player_id = player_id
	event.effect_id = effect_id
	event.effect_position = effect_position
	logic.spawn_event(event)
	if attacker_player_id != "":
		logic.record_damage(attacker_player_id, damage * damage_multiplier)
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	logic.call_deferred("respawn_player", player_id)


func _update_reload_times(delta: float) -> void:
	if melee_recharge_time > 0.0:
		melee_recharge_time -= delta
		var melee = Data.MELEE[melee_id]
		if melee_recharge_time <= 0.0:
			if melee.max_ammunition > melee_ammunition:
				melee_ammunition += 1
				if melee.max_ammunition > melee_ammunition:
					melee_recharge_time = melee.reload_time
	if ranged_recharge_time > 0.0:
		ranged_recharge_time -= delta
		var ranged = Data.RANGED[ranged_id]
		if ranged_recharge_time <= 0.0:
			if ranged.max_ammunition > ranged_ammunition:
				ranged_ammunition += 1
				if ranged.max_ammunition > ranged_ammunition:
					ranged_recharge_time = ranged.reload_time


func _update_attack_time(delta: float) -> void:
	if attack_time_left <= 0.0:
		return
	attack_time_left -= delta
	if attack_time_left <= 0.0:
		attack_time_left = 0.0
		attacking = false
		hitbox_collision_shape.set_deferred("disabled", true)


func _update_burst_time(delta: float) -> void:
	if burst_time_left <= 0.0:
		return
	burst_time_left -= delta
	if burst_time_left <= 0.0:
		burst_time_left = 0.0
		_fire_shot()


func _apply_horizontal_movement(delta: float, direction: int) -> void:
	if direction != 0:
		var speed_multiplier := Data.ARMOUR[armour_id].speed_multiplier
		velocity.x = move_toward(velocity.x, direction * SPEED * speed_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)


func _apply_vertical_movement(delta: float, jumping: bool) -> void:
	if is_on_floor():
		jumping_grace_time_left = JUMPING_GRACE
	else:
		jumping_grace_time_left -= delta
		velocity.y += GRAVITY * delta
	if jumping and (is_on_floor() or jumping_grace_time_left > 0.0):
		var jump_multiplier := Data.ARMOUR[armour_id].jump_multiplier
		velocity.y = JUMP_FORCE * jump_multiplier
		jumping_grace_time_left = 0.0


func _start_melee_attack() -> void:
	var melee: Melee = Data.MELEE[melee_id]
	melee_ammunition -= 1
	if melee_recharge_time <= 0.0:
		melee_recharge_time = melee.reload_time
	
	attack_time_left = melee.attack_duration
	pivot.rotation = aim_direction.angle()
	hitbox_collision_shape.shape.size = melee.hitbox_size
	hitbox_collision_shape.position.x = melee.hitbox_size.x / 2
	hitbox_collision_shape.set_deferred("disabled", false)


func _start_ranged_attack() -> void:
	var ranged: Ranged = Data.RANGED[ranged_id]
	ranged_ammunition -= 1
	if ranged_recharge_time <= 0.0:
		ranged_recharge_time = ranged.reload_time
	
	attack_time_left = ranged.attack_duration
	burst_bullet_amount = ranged.bullet_amount
	_fire_shot()


func _fire_shot() -> void:
	var ranged: Ranged = Data.RANGED[ranged_id]
	var offset: Vector2 = ranged.bullet_offset
	offset.y *= facing
	var bullet_position: Vector2 = pivot.global_position + offset.rotated(aim_direction.angle())
	logic.spawn_bullet(
		bullet_position,
		ranged.bullet_speed,
		ranged.bullet_damage,
		ranged.self_hit,
		ranged.bullet_range,
		aim_direction,
		player_id,
	)
	burst_bullet_amount -= 1
	if burst_bullet_amount > 0:
		burst_time_left = ranged.attack_duration / ranged.bullet_amount


func _update_facing() -> void:
	var weapon: Weapon
	if current_weapon == 0:
		weapon = Data.MELEE[melee_id]
	else:
		weapon = Data.RANGED[ranged_id]
	if weapon.moonwalk and aim_direction != Vector2.ZERO:
		if aim_direction.x > 0:
			facing = 1
		else:
			facing = -1
	else:
		if velocity.x > 0:
			facing = 1
		elif velocity.x < 0:
			facing = -1


func _ability_double_jump() -> void:
	last_ability = logic.tick
	var armour_jump_multiplier := Data.ARMOUR[armour_id].jump_multiplier
	var dash_jump_multiplier: float = Data.ABILITY[ability_id].jump_multiplier
	velocity.y = JUMP_FORCE * armour_jump_multiplier * dash_jump_multiplier


func _ability_dash(direction: int) -> void:
	last_ability = logic.tick
	var dash_direction: int
	if direction != 0:
		dash_direction = direction
	else:
		dash_direction = facing
	var distance: int = Data.ABILITY[ability_id].distance
	move_and_collide(Vector2(dash_direction, 0) * distance)


func _ability_invisibility() -> void:
	ability_active = true
	ability_time_left = Data.ABILITY[ability_id].duration


func _ability_update_invisibility(delta) -> void:
	ability_time_left -= delta
	if ability_time_left <= 0.0:
		ability_active = false


func _ability_slam_down() -> void:
	ability_active = true


func _ability_update_slam_down(delta) -> void:
	var speed: int = Data.ABILITY[ability_id].speed
	velocity.y = speed
	velocity.x = 0
	if is_on_floor():
		for area in slam_down_area.get_overlapping_areas():
			if area.get_parent() == self:
				continue
			var damage: int = Data.ABILITY[ability_id].damage
			var knockback: int = Data.ABILITY[ability_id].knockback
			area.get_parent().apply_hit(damage, player_id)
			area.get_parent().apply_knockback(slam_down_marker.global_position, knockback)
		ability_active = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not attacking:
		return
	var weapon: Weapon
	if current_weapon == 0:
		weapon = Data.MELEE[melee_id]
	else:
		weapon = Data.RANGED[ranged_id]
	if not weapon.self_hit and area.get_parent() == self:
		return
	var effect_id := weapon.effect_id
	var effect_position: Vector2 = pivot.global_position.lerp(area.get_parent().pivot.global_position, 0.5)
	area.get_parent().apply_hit(weapon.damage, player_id, effect_id, effect_position)
	area.get_parent().apply_knockback(pivot.global_position, weapon.knockback)


func _on_arena_area_exited(area: Area2D) -> void:
	_die()


func _get_auto_aim_direction() -> Vector2:
	var auto_aim_direction := Vector2.RIGHT
	var shortest_distance_squared := INF
	for player in logic.players.values():
		if player == self:
			continue
		var player_position: Vector2 = player.pivot.global_position
		var distance: float = player_position.distance_squared_to(pivot.global_position)
		if distance < shortest_distance_squared:
			auto_aim_direction = pivot.global_position.direction_to(player_position)
			shortest_distance_squared = distance
	return auto_aim_direction
