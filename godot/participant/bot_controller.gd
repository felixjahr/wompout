class_name BotController
extends RefCounted

# Combat knowledge comes exclusively from snapshots. Physics probes only inspect
# terrain (layer 1), so the controller never reads live participant state.
const BODY_HALF_HEIGHT := 104.0
const PIVOT_OFFSET := Vector2(0, -52)
const GRAVITY := 1500.0
const JUMP_SPEED := 1200.0

var _rng := RandomNumberGenerator.new()
var _initialized := false
var _target_id := ""
var _think_left := 0.0
var _attack_left := 0.0
var _jump_left := 0.0
var _ability_left := 0.0
var _strafe_left := 0.0
var _strafe := 1
var _aim_error := 0.0
var _aim := Vector2.RIGHT
var _observed_position := Vector2.ZERO
var _observed_velocity := Vector2.ZERO
var _last_position := Vector2.ZERO
var _stuck_time := 0.0
var _last_tick := -1
var _space: PhysicsDirectSpaceState2D


func get_input(participant_id: String, snapshot: Snapshot, delta: float) -> ParticipantInput:
	var input := ParticipantInput.new()
	if snapshot == null:
		return input
	input.tick = snapshot.tick
	var me: ParticipantSnapshot
	for participant in snapshot.participants:
		if participant.participant_id == participant_id:
			me = participant
			break
	if me == null or me.health <= 0 or me.hearts <= 0:
		_target_id = ""
		return input
	if not _initialized or snapshot.tick < _last_tick or me.position.distance_to(_last_position) > 900.0:
		_rng.seed = hash(participant_id)
		_initialized = true
		_target_id = ""
		_think_left = 0.0
		_attack_left = 0.3
		_stuck_time = 0.0
		_aim = Vector2(me.facing if me.facing != 0 else 1, 0)
	_last_tick = snapshot.tick
	var elapsed := clampf(delta, 0.0, 0.1)
	_think_left -= elapsed
	_attack_left -= elapsed
	_jump_left -= elapsed
	_ability_left -= elapsed
	_strafe_left -= elapsed
	_space = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		_space = tree.root.world_2d.direct_space_state

	var target: ParticipantSnapshot
	for participant in snapshot.participants:
		if participant.participant_id == _target_id and _is_enemy(me, participant):
			target = participant
			break
	if _think_left <= 0.0:
		var best_score := INF
		for candidate in snapshot.participants:
			if not _is_enemy(me, candidate):
				continue
			var score := me.position.distance_to(candidate.position)
			if candidate.participant_id == _target_id:
				score *= 0.7 # Commit to a duel instead of flicking between players.
			if not _clear(me.position + PIVOT_OFFSET, candidate.position + PIVOT_OFFSET):
				score += 450.0
			if score < best_score:
				best_score = score
				target = candidate
		if target != null:
			if _target_id != target.participant_id:
				_attack_left = maxf(_attack_left, 0.25)
			_target_id = target.participant_id
			_observed_position = target.position
			_observed_velocity = target.velocity
		_aim_error = _rng.randf_range(-0.065, 0.065)
		_think_left = _rng.randf_range(0.16, 0.28)
	if target == null:
		_target_id = ""
		_last_position = me.position
		return input

	var melee: Melee = Data.MELEE.get(me.melee_id)
	var ranged: Ranged = Data.RANGED.get(me.ranged_id)
	var armour: Armour = Data.ARMOUR.get(me.armour_id)
	var speed := 500.0 * (armour.speed_multiplier if armour != null else 1.0)
	var jump_speed := JUMP_SPEED * (armour.jump_multiplier if armour != null else 1.0)
	var offset := _observed_position - me.position
	var distance := offset.length()
	var melee_range := melee.hitbox_size.x + 15.0 if melee != null else 140.0
	var use_melee := me.melee_ammunition > 0 and distance < melee_range
	input.current_weapon = 0 if use_melee or me.ranged_ammunition <= 0 else 1
	var lead := 0.0
	if input.current_weapon == 1 and ranged != null:
		lead = clampf(distance / maxf(ranged.bullet_speed, 1.0), 0.0, 0.45) * 0.75
	var aim_point := _observed_position + _observed_velocity * lead
	var desired_aim := me.position.direction_to(aim_point).rotated(_aim_error)
	_aim = _aim.rotated(clampf(_aim.angle_to(desired_aim), -5.0 * elapsed, 5.0 * elapsed)).normalized()
	input.aim_direction = _aim

	if _strafe_left <= 0.0:
		_strafe = -1 if _rng.randf() < 0.5 else 1
		_strafe_left = _rng.randf_range(0.7, 1.5)
	var toward := int(signf(offset.x))
	var preferred_range := 430.0 if ranged != null and me.ranged_ammunition > 0 else melee_range * 0.65
	if me.health < 35 and me.ranged_ammunition > 0:
		preferred_range += 180.0
	var visible := _clear(me.position + PIVOT_OFFSET, _observed_position + PIVOT_OFFSET)
	if absf(offset.x) > preferred_range + 90.0 or not visible:
		input.direction = toward
	elif absf(offset.x) < preferred_range - 100.0 and not use_melee:
		input.direction = -toward
	else:
		input.direction = _strafe if not use_melee else toward

	var danger := _incoming_bullet(me, snapshot)
	if me.is_on_floor and absf(me.position.x - _last_position.x) < 2.0 and input.direction != 0:
		_stuck_time += elapsed
	else:
		_stuck_time = 0.0
	_last_position = me.position
	var feet := me.position + Vector2(0, BODY_HALF_HEIGHT)
	var look_ahead := maxf(90.0, absf(me.velocity.x) * 0.25)
	var ahead := feet + Vector2(input.direction * look_ahead, 0)
	var floor_hit := _ray(ahead - Vector2(0, 30), ahead + Vector2(0, 170))
	var wall := not _clear(me.position, me.position + Vector2(input.direction * 100, 0))
	var hazard := false
	if not floor_hit.is_empty():
		var collider: Object = floor_hit.collider
		hazard = collider is Node and "spike" in String(collider.name).to_lower()
	var wants_jump := wall or hazard or _stuck_time > 0.45 or danger
	wants_jump = wants_jump or (offset.y < -150.0 and absf(offset.x) < 650.0)
	if _space != null and me.is_on_floor and input.direction != 0 and floor_hit.is_empty():
		# Seek a reachable landing before committing to a gap. This also lets
		# the bot take a lower platform when pursuing someone below it.
		var landing := _landing(feet, input.direction, speed, jump_speed)
		if landing.is_empty():
			input.direction = -int(signf(me.velocity.x)) if absf(me.velocity.x) > 60.0 else 0
			wants_jump = false
		else:
			wants_jump = true
	if me.is_on_floor and wants_jump and _jump_left <= 0.0:
		input.jumping = true
		_jump_left = _rng.randf_range(0.65, 1.0)
		_stuck_time = 0.0
	# Brake an airborne overshoot, or steer toward the nearest floor below.
	if _space != null and not me.is_on_floor and me.velocity.y > 0.0:
		var below := _ray(feet, feet + Vector2(0, 700))
		if below.is_empty():
			for direction in [toward, -toward]:
				if direction == 0:
					continue
				var landing := _landing(feet, direction, speed, maxf(0.0, -me.velocity.y))
				if not landing.is_empty():
					input.direction = direction
					break

	var in_range := use_melee
	if input.current_weapon == 1 and ranged != null:
		in_range = distance > ranged.bullet_offset.x * 0.8 and distance < ranged.bullet_range * 0.9
	if in_range and visible and not me.attacking and _attack_left <= 0.0 and absf(_aim.angle_to(desired_aim)) < 0.15:
		input.attacking = true
		_attack_left = _rng.randf_range(0.22, 0.48)
		if input.current_weapon == 1 and ranged != null:
			_attack_left += ranged.attack_duration
		elif melee != null:
			_attack_left += melee.attack_duration
	var ability: Ability = Data.ABILITY.get(me.ability_id)
	if ability != null and me.ability_charge >= ability.charge and not me.ability_active and _ability_left <= 0.0:
		match me.ability_id:
			"dash":
				var dash_end := me.position + Vector2(input.direction * float(ability.get("distance")), 0)
				input.ability = input.direction != 0 and (danger or (distance > 400.0 and distance < 850.0)) and _clear(me.position, dash_end) and not _ray(dash_end, dash_end + Vector2(0, 350)).is_empty()
			"invisibility":
				input.ability = visible and (me.health < 45 or distance < 550.0)
			"double_jump":
				input.ability = not me.is_on_floor and me.velocity.y > 50.0 and (offset.y < -180.0 or _ray(feet, feet + Vector2(0, 650)).is_empty())
			"slam_down":
				input.ability = not me.is_on_floor and offset.y > 150.0 and offset.y < 500.0 and absf(offset.x) < 100.0 and visible
		if input.ability:
			_ability_left = 1.0
	return input


func _is_enemy(me: ParticipantSnapshot, other: ParticipantSnapshot) -> bool:
	return other.participant_id != me.participant_id and other.team_id != me.team_id and other.health > 0 and other.hearts > 0 and not (other.ability_id == "invisibility" and other.ability_active)


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	if _space == null:
		return {}
	return _space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1))


func _clear(from: Vector2, to: Vector2) -> bool:
	return _ray(from, to).is_empty()


func _landing(feet: Vector2, direction: int, speed: float, jump_speed: float) -> Dictionary:
	for reach in [150.0, 280.0, 420.0, 580.0]:
		var x: float = feet.x + direction * reach
		var flight_time: float = reach / maxf(speed, 1.0)
		var rise := jump_speed * flight_time - 0.5 * GRAVITY * flight_time * flight_time
		var hit := _ray(Vector2(x, feet.y - maxf(rise, 0.0)), Vector2(x, feet.y + 450.0))
		if hit.is_empty():
			continue
		var point: Vector2 = hit.position
		var collider: Object = hit.collider
		if collider is Node and "spike" in String(collider.name).to_lower():
			continue
		if point.y >= feet.y - rise + 20.0 and hit.normal.y < -0.5:
			return hit
	return {}


func _incoming_bullet(me: ParticipantSnapshot, snapshot: Snapshot) -> bool:
	# No owner information is exposed in BulletSnapshot. Only approaching
	# trajectories count, so bullets just fired away from us are ignored.
	for bullet in snapshot.bullets:
		var relative := bullet.position - me.position
		var velocity := bullet.direction * bullet.speed - me.velocity
		if velocity.length_squared() < 1.0:
			continue
		var time := -relative.dot(velocity) / velocity.length_squared()
		if time > 0.12 and time < 0.42:
			var closest := relative + velocity * time
			if absf(closest.x) < 65.0 and absf(closest.y) < 115.0:
				return true
	return false
