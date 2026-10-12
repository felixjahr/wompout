class_name BotController
extends RefCounted

# Closed controller: only setup(), receive_snapshot(), and get_input() accept
# external state. Map instances never enter the tree; snapshots/resources are
# read-only. Cached geometry/graphs contain only values owned by this script.
# Flow: observe -> choose a tactical destination -> commit to a traversal ->
# steer and fight. Randomness changes preferences and timing, never map safety.
enum Tactic { ROAM, HUNT, ENGAGE, RETREAT }
enum Difficulty { EASY, MEDIUM, HARD }

# The previous tuning sits between MEDIUM and HARD. Ranges preserve individual
# personalities within each level; geometry and safe traversal are identical.
const DIFFICULTY_PROFILES := {
	Difficulty.EASY: {
		"reaction": Vector2(0.38, 0.58), "accuracy": Vector2(0.09, 0.14),
		"turn_speed": Vector2(2.5, 3.8), "lead": Vector2(0.50, 0.68),
		"melee_aggression": Vector2(0.15, 0.30),
	},
	Difficulty.MEDIUM: {
		"reaction": Vector2(0.23, 0.34), "accuracy": Vector2(0.045, 0.075),
		"turn_speed": Vector2(3.6, 5.2), "lead": Vector2(0.72, 0.84),
		"melee_aggression": Vector2(0.40, 0.60),
	},
	Difficulty.HARD: {
		"reaction": Vector2(0.14, 0.21), "accuracy": Vector2(0.012, 0.028),
		"turn_speed": Vector2(5.5, 7.0), "lead": Vector2(0.88, 0.97),
		"melee_aggression": Vector2(0.70, 0.90),
	},
}

# Keep these in step with ParticipantServer's movement and capsule. There is no
# live participant dependency, including during local prediction/route testing.
const SPEED := 500.0
const ACCELERATION := 4000.0
const FRICTION := 5000.0
const GRAVITY := 1800.0
const JUMP_SPEED := 1300.0
const HALF_HEIGHT := 104.0
const RADIUS := 24.0
const PIVOT := Vector2(0, -52)
const STEP := 1.0 / 30.0
const MEMORY_SECONDS := 2.8
const STALE_SECONDS := 0.65

static var _map_cache: Dictionary = {}
static var _graph_cache: Dictionary = {}
static var _graph_builders: Dictionary = {}

var _participant_id := ""
var _map_id := ""
var _mode_id := ""
var _rng := RandomNumberGenerator.new()
var _geometry: Array = []
var _surfaces: Array = []
var _arena := Rect2(-10000, -10000, 20000, 20000)
var _graph: Array = []
var _graph_key := ""

var _me: Dictionary = {}
var _people: Array = []
var _contacts: Dictionary = {}
var _bullets: Array = []
var _bullet_seen: Dictionary = {}
var _tick := -1
var _clock := 0.0
var _snapshot_at := -INF
var _position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _grounded := false
var _speed := SPEED
var _jump_speed := JUMP_SPEED
var _aim := Vector2.RIGHT
var _target_id := ""
var _tactic := Tactic.ROAM
var _goal := Vector2.ZERO
var _goal_surface := -1
var _edge: Dictionary = {}
var _flight := false
var _flight_at := 0.0
var _left_floor := false
var _double_used := false
var _think_at := 0.0
var _plan_at := 0.0
var _shoot_at := 0.0
var _jump_at := 0.0
var _ability_at := 0.0
var _strafe_at := 0.0
var _strafe := 0
var _aim_error := 0.0
var _stuck := 0.0
var _last_observed := Vector2.ZERO
var _last_direction := 0
var _last_health := 100
var _hurt_at := -INF
var _retreat_until := 0.0
var _retreat_again_at := 0.0
var _recover_until := 0.0
var _recover_x := 0.0
var _danger: Dictionary = {}
var _air_plan_at := 0.0
var _air_x := 0.0
var _hop_requested := false
var _melee_until := 0.0
var _melee_decide_at := 0.0

# Drawn once per setup, with small variations on each decision. Independent RNGs
# avoid identical bots or repeating the same participant's behavior next match.
var _aggression := 0.5
var _spacing := 1.0
var _reaction := 0.2
var _accuracy := 0.04
var _turn_speed := 5.0
var _mobility := 0.5
var _teamwork := 0.5
var _melee_aggression := 0.5
var _lead := 0.8


func setup(participant_id: String, map_id: String, mode_id: String, difficulty: Difficulty = Difficulty.MEDIUM) -> void:
	_participant_id = participant_id
	_map_id = map_id
	_mode_id = mode_id
	_rng.randomize()
	var profile: Dictionary = DIFFICULTY_PROFILES.get(difficulty, DIFFICULTY_PROFILES[Difficulty.MEDIUM])
	_aggression = _rng.randf_range(0.25, 0.85)
	_spacing = _rng.randf_range(0.82, 1.18)
	_reaction = _sample_range(profile.reaction)
	_accuracy = _sample_range(profile.accuracy)
	_turn_speed = _sample_range(profile.turn_speed)
	_lead = _sample_range(profile.lead)
	_melee_aggression = _sample_range(profile.melee_aggression)
	_mobility = _rng.randf_range(0.4, 0.9)
	_teamwork = _rng.randf_range(0.3, 0.9)
	_clock = 0.0
	_tick = -1
	_snapshot_at = -INF
	_me = {}
	_people = []
	_contacts = {}
	_bullets = []
	_bullet_seen = {}
	_graph = []
	_graph_key = ""
	_reset_life()
	_load_map()


func _sample_range(bounds: Vector2) -> float:
	return _rng.randf_range(bounds.x, bounds.y)


func receive_snapshot(snapshot: Snapshot) -> void:
	if snapshot == null or snapshot.tick <= _tick:
		return
	_tick = snapshot.tick
	var elapsed := maxf(0.0, _clock - _snapshot_at)
	_snapshot_at = _clock
	_people = []
	var self_state: Dictionary = {}
	for participant in snapshot.participants:
		var copy := _copy_participant(participant)
		_people.append(copy)
		if participant.participant_id == _participant_id:
			self_state = copy
	if self_state.is_empty():
		_me = {}
		return
	var respawned := _me.is_empty()
	if not _me.is_empty():
		respawned = int(self_state.hearts) != int(_me.hearts) or (int(_me.health) <= 0 and int(self_state.health) > 0)
		# Dash/knockback are ordinary motion. Only a large discontinuity resets a life.
		respawned = respawned or Vector2(self_state.position).distance_to(_position) > 1500.0
	_me = self_state
	if respawned:
		_reset_life()
		_last_health = int(_me.health)
		_last_observed = _me.position
		_aim = Vector2(float(_me.facing) if int(_me.facing) != 0 else 1.0, 0)
	if int(_me.health) < _last_health:
		_hurt_at = _clock
	_last_health = int(_me.health)
	_position = _me.position
	_velocity = _me.velocity
	_grounded = _me.floor
	var armour: Armour = Data.ARMOUR.get(_me.armour)
	_speed = SPEED * (armour.speed_multiplier if armour != null else 1.0)
	_jump_speed = JUMP_SPEED * (armour.jump_multiplier if armour != null else 1.0)
	if _grounded and _last_direction != 0 and _position.distance_to(_last_observed) < 5.0:
		_stuck += minf(elapsed, 0.2)
	else:
		_stuck = maxf(0.0, _stuck - 0.15)
	_last_observed = _position
	_observe_people()
	_bullets = []
	var seen_now: Dictionary = {}
	for bullet in snapshot.bullets:
		if not _bullet_seen.has(bullet.bullet_id):
			_bullet_seen[bullet.bullet_id] = _clock
		seen_now[bullet.bullet_id] = _bullet_seen[bullet.bullet_id]
		_bullets.append({"position": bullet.position, "velocity": bullet.direction * bullet.speed,
			"weapon": bullet.weapon_id, "seen": _bullet_seen[bullet.bullet_id]})
	_bullet_seen = seen_now


func get_input(delta: float) -> ParticipantInput:
	var input := ParticipantInput.new()
	var dt := clampf(delta, 0.0, 0.1)
	_clock += dt
	input.tick = maxi(_tick, 0)
	input.aim_direction = _aim
	if _me.is_empty() or int(_me.health) <= 0 or int(_me.hearts) <= 0:
		return input
	# Do not continue firing/running on a disconnected observation stream.
	if _clock - _snapshot_at > STALE_SECONDS or _surfaces.is_empty():
		return input
	_ensure_graph()
	if _clock >= _think_at:
		_choose_tactic()
		_hop_requested = _grounded and _tactic == Tactic.ENGAGE and _rng.randf() < _mobility * 0.03
		_danger = _incoming_threat()
		_aim_error = lerpf(_aim_error, _rng.randfn(0.0, _accuracy), 0.65)
		_think_at = _clock + _reaction * _rng.randf_range(0.45, 0.75)
	if _clock >= _plan_at and not _flight:
		_choose_destination()
		_plan_at = _clock + _rng.randf_range(0.65, 1.15)
	_move(input)
	_combat(input, dt)
	_use_ability(input)
	_last_direction = input.direction
	_predict(input, dt)
	return input


func _reset_life() -> void:
	_target_id = ""
	_contacts.clear()
	_tactic = Tactic.ROAM
	_edge = {}
	_flight = false
	_double_used = false
	_goal_surface = -1
	_think_at = _clock
	_plan_at = _clock
	_shoot_at = _clock + _reaction
	_jump_at = _clock
	_ability_at = _clock
	_strafe_at = _clock
	_strafe = 0
	_stuck = 0.0
	_last_direction = 0
	_hurt_at = -INF
	_retreat_until = _clock
	_retreat_again_at = _clock
	_recover_until = 0.0
	_danger = {}
	_air_plan_at = _clock
	_aim_error = 0.0
	_hop_requested = false
	_melee_until = _clock
	_melee_decide_at = _clock


func _copy_participant(p: ParticipantSnapshot) -> Dictionary:
	return {"id": p.participant_id, "team": p.team_id, "position": p.position,
		"velocity": p.velocity, "floor": p.is_on_floor, "health": p.health,
		"hearts": p.hearts, "facing": p.facing, "attacking": p.attacking,
		"aim": p.aim_direction, "weapon": p.current_weapon,
		"melee": p.melee_id, "melee_ammo": p.melee_ammunition,
		"ranged": p.ranged_id, "ranged_ammo": p.ranged_ammunition,
		"melee_reload": p.melee_recharge_time, "ranged_reload": p.ranged_recharge_time,
		"armour": p.armour_id, "ability": p.ability_id,
		"charge": p.ability_charge, "active": p.ability_active}


# Map extraction: off-tree instances include nested PackedScenes and transforms,
# without running _ready(), enabling physics, or altering the actual map.
func _load_map() -> void:
	_geometry = []
	_surfaces = []
	_arena = Rect2(-10000, -10000, 20000, 20000)
	if _map_cache.has(_map_id):
		var cached: Dictionary = _map_cache[_map_id]
		_geometry = cached.geometry
		_surfaces = cached.surfaces
		_arena = cached.arena
		return
	var scene: PackedScene = Data.MAPS.get(_map_id)
	if scene == null:
		return
	var root := scene.instantiate()
	_collect_geometry(root, Transform2D.IDENTITY, false)
	root.free()
	_build_surfaces()
	_map_cache[_map_id] = {"geometry": _geometry, "surfaces": _surfaces, "arena": _arena}


func _collect_geometry(node: Node, parent_transform: Transform2D, inherited_hazard: bool) -> void:
	var transform := parent_transform
	if node is Node2D:
		transform = parent_transform * node.transform
	var hazard := inherited_hazard or node.is_in_group("hazard") or node.is_in_group("hazards")
	# Existing maps identify spikes through their scene name/damage property.
	hazard = hazard or "spike" in String(node.name).to_lower() or node.get_meta("hazard", false) == true
	var polygon := PackedVector2Array()
	var one_way := false
	if node is CollisionPolygon2D and not node.disabled:
		polygon = node.polygon
		one_way = node.one_way_collision
	elif node is CollisionShape2D and not node.disabled and node.shape != null:
		polygon = _shape_polygon(node.shape)
		one_way = node.one_way_collision
	if polygon.size() >= 3:
		var points := transform * polygon
		var parent := node.get_parent()
		if parent is Area2D and (parent.collision_layer & 4) != 0:
			_arena = _bounds(points)
		elif (parent is StaticBody2D and (parent.collision_layer & 1) != 0) or hazard:
			_geometry.append({"points": points, "bounds": _bounds(points), "one_way": one_way, "hazard": hazard})
	for child in node.get_children():
		_collect_geometry(child, transform, hazard)


func _shape_polygon(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var h: Vector2 = shape.size * 0.5
		return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	if shape is ConvexPolygonShape2D:
		return shape.points
	var points := PackedVector2Array()
	if shape is CircleShape2D or shape is CapsuleShape2D:
		var radius: float = shape.radius
		var extension: float = maxf(0.0, shape.height * 0.5 - radius) if shape is CapsuleShape2D else 0.0
		for i in 24:
			var angle := TAU * float(i) / 24.0
			var point := Vector2.from_angle(angle) * radius
			point.y += extension * signf(point.y)
			points.append(point)
	return points


func _bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _build_surfaces() -> void:
	for geometry in _geometry:
		if geometry.hazard:
			continue
		var polygon: PackedVector2Array = geometry.points
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			if a.x > b.x:
				var swap := a
				a = b
				b = swap
			if b.x - a.x < RADIUS * 2.0 + 12.0 or absf(b.y - a.y) > (b.x - a.x) * 0.65:
				continue
			var middle := (a + b) * 0.5
			if Geometry2D.is_point_in_polygon(middle + Vector2(0, -2), polygon):
				continue
			if not Geometry2D.is_point_in_polygon(middle + Vector2(0, 2), polygon):
				continue
			# Split surfaces around hazards, walls, and insufficient headroom.
			var left := a.x + RADIUS + 8.0
			var right := b.x - RADIUS - 8.0
			var count := maxi(1, ceili((right - left) / 24.0))
			var start := INF
			var last := left
			for sample in range(count + 1):
				var x := lerpf(left, right, float(sample) / count)
				var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
				var center := Vector2(x, y - HALF_HEIGHT - 0.5)
				var safe := _arena.has_point(center) and _body_clear(center) and not _hazard_at(center)
				if safe:
					if start == INF:
						start = x
					last = x
				if (not safe or sample == count) and start != INF:
					if last - start > 16.0:
						_surfaces.append({"left": start, "right": last, "a": a, "b": b})
					start = INF


func _surface_y(surface: Dictionary, x: float) -> float:
	var a: Vector2 = surface.a
	var b: Vector2 = surface.b
	return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))


func _surface_point(index: int, x: float) -> Vector2:
	var surface: Dictionary = _surfaces[index]
	x = clampf(x, surface.left, surface.right)
	return Vector2(x, _surface_y(surface, x) - HALF_HEIGHT - 0.5)


func _surface_at(position: Vector2, tolerance := 24.0) -> int:
	var best := -1
	var distance := tolerance
	for i in _surfaces.size():
		var s: Dictionary = _surfaces[i]
		if position.x < float(s.left) - 12.0 or position.x > float(s.right) + 12.0:
			continue
		var gap := absf(position.y + HALF_HEIGHT - _surface_y(s, position.x))
		if gap < distance:
			best = i
			distance = gap
	return best


func _body_clear(position: Vector2) -> bool:
	# A slightly inset capsule outline keeps resting contacts out of obstacles.
	# Segment tests catch thin walls; point tests catch being inside a solid.
	var outline := PackedVector2Array([
		position + Vector2(0, -103), position + Vector2(22, -80),
		position + Vector2(22, 80), position + Vector2(0, 103),
		position + Vector2(-22, 80), position + Vector2(-22, -80)])
	var bounds := Rect2(position - Vector2(23, 103), Vector2(46, 206))
	for g in _geometry:
		if g.one_way or not bounds.intersects(g.bounds):
			continue
		var polygon: PackedVector2Array = g.points
		for point in outline:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return false
		for i in polygon.size():
			if bounds.has_point(polygon[i]) and Geometry2D.is_point_in_polygon(polygon[i], outline):
				return false
			if not bounds.intersects(Rect2(polygon[i], Vector2.ZERO).expand(polygon[(i + 1) % polygon.size()]).grow(0.1)):
				continue
			for j in outline.size():
				if Geometry2D.segment_intersects_segment(polygon[i], polygon[(i + 1) % polygon.size()], outline[j], outline[(j + 1) % outline.size()]) != null:
					return false
	return true


func _hazard_at(position: Vector2) -> bool:
	var bounds := Rect2(position - Vector2(34, 112), Vector2(68, 224))
	for g in _geometry:
		if g.hazard and bounds.intersects(g.bounds):
			return true
	return false


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var closest := INF
	var result: Dictionary = {}
	var bounds := Rect2(from, Vector2.ZERO).expand(to).grow(0.1)
	for g in _geometry:
		if not bounds.intersects(g.bounds):
			continue
		var polygon: PackedVector2Array = g.points
		if Geometry2D.is_point_in_polygon(from, polygon):
			return {"position": from}
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(from, to, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				var distance := from.distance_squared_to(hit)
				if distance < closest:
					closest = distance
					result = {"position": Vector2(hit)}
	return result


func _visible(from: Vector2, to: Vector2) -> bool:
	return _ray(from + PIVOT, to + PIVOT).is_empty()


# Navigation uses the same acceleration, braking and jump model as execution.
# Each directed edge stores a launch point and a landing destination. Testing
# the whole capsule path rejects ceilings, walls, spikes and intervening floors.
func _steer(position: Vector2, velocity: Vector2, x: float) -> int:
	var dx := x - position.x
	var stopping := velocity.x * velocity.x / (2.0 * FRICTION)
	if absf(dx) < 9.0 or (signf(dx) == signf(velocity.x) and absf(dx) < stopping + 8.0):
		return 0
	return int(signf(dx))


func _motion(position: Vector2, velocity: Vector2, direction: int, dt: float, apply_gravity := true) -> Dictionary:
	velocity.x = move_toward(velocity.x, direction * _speed, (ACCELERATION if direction != 0 else FRICTION) * dt)
	if apply_gravity:
		velocity.y += GRAVITY * dt
	var next := position + velocity * dt
	# Handle sides separately, so an unexpected wall does not freeze gravity.
	if not _body_clear(Vector2(next.x, position.y)):
		next.x = position.x
		velocity.x = 0.0
	var landing := -1
	if velocity.y >= 0.0:
		var best_y := INF
		for i in _surfaces.size():
			var s: Dictionary = _surfaces[i]
			# Allow capsule support near an edge during a planned walk-off.
			if next.x < float(s.left) - 54.0 or next.x > float(s.right) + 54.0:
				continue
			var y := _surface_y(s, next.x) - HALF_HEIGHT - 0.5
			if position.y <= y + 2.0 and next.y >= y and y < best_y:
				best_y = y
				landing = i
		if landing >= 0:
			next.y = best_y
			velocity.y = 0.0
	if not _body_clear(next):
		next.y = position.y
		velocity.y = 0.0
	return {"position": next, "velocity": velocity, "surface": landing}


func _simulate(start: Vector2, velocity: Vector2, x: float, jump: bool, double_jump := false) -> Dictionary:
	var position := start
	if jump:
		velocity.y = -_jump_speed
	var airborne := jump or _surface_at(start) < 0
	var used_double := false
	for step in 84:
		var gravity_this_step := not (jump and step == 0)
		if double_jump and not used_double and airborne and velocity.y > -80.0:
			var ability: DoubleJump = Data.ABILITY.get("double_jump")
			velocity.y = -_jump_speed * ability.jump_multiplier
			used_double = true
			gravity_this_step = false
		var motion := _motion(position, velocity, _steer(position, velocity, x), STEP, gravity_this_step)
		position = motion.position
		velocity = motion.velocity
		if _hazard_at(position) or not _arena.has_point(position):
			return {}
		if int(motion.surface) < 0:
			airborne = true
		elif airborne:
			var s: Dictionary = _surfaces[int(motion.surface)]
			if position.x < float(s.left) or position.x > float(s.right):
				return {}
			return {"surface": int(motion.surface), "position": position, "time": (step + 1) * STEP}
	return {}


func _ability_ready() -> bool:
	var ability: Ability = Data.ABILITY.get(_me.get("ability", ""))
	return ability != null and int(_me.get("charge", 0)) >= ability.charge and not bool(_me.get("active", false)) and _clock >= _ability_at


func _ensure_graph() -> void:
	var double_jump: bool = _me.ability == "double_jump" and _ability_ready()
	var key := "%s:%.3f:%.3f:%s" % [_map_id, _speed, _jump_speed, double_jump]
	if key == _graph_key and _graph_cache.has(key):
		return
	_graph_key = key
	if _graph_cache.has(key):
		_graph = _graph_cache[key]
		return
	if not _graph_builders.has(key):
		var edges: Array = []
		for i in _surfaces.size():
			edges.append([])
		_graph_builders[key] = {"edges": edges, "pair": 0, "candidates": [], "best": {}}
	var builder: Dictionary = _graph_builders[key]
	_graph = builder.edges
	# Amortize cold route discovery; subsequent bots share the finished graph.
	# A single trajectory is the smallest work unit. Never block a tick building
	# every armour/ability combination, and keep fighting while routes fill in.
	var deadline := Time.get_ticks_usec() + 1500
	while Time.get_ticks_usec() < deadline:
		if builder.candidates.is_empty():
			if int(builder.pair) > 0 and not builder.best.is_empty():
				var best: Dictionary = builder.best
				_graph[int(best.from)].append(best)
				builder.best = {}
			if int(builder.pair) >= _surfaces.size() * _surfaces.size():
				_graph_cache[key] = _graph
				_graph_builders.erase(key)
				_plan_at = _clock
				return
			var pair: int = builder.pair
			builder.pair = pair + 1
			builder.candidates = _edge_candidates(pair / _surfaces.size(), pair % _surfaces.size(), double_jump)
			continue
		var candidate: Dictionary = builder.candidates.pop_back()
		var result := _simulate(candidate.launch, Vector2.ZERO, candidate.x, candidate.jump, candidate.double)
		if result.is_empty() or int(result.surface) != int(candidate.to):
			continue
		candidate.cost += float(result.time)
		if builder.best.is_empty() or float(candidate.cost) < float(builder.best.cost):
			builder.best = candidate


func _edge_candidates(from: int, to: int, double_jump: bool) -> Array:
	var candidates: Array = []
	if from == to:
		return candidates
	var source: Dictionary = _surfaces[from]
	var target: Dictionary = _surfaces[to]
	var middle := (float(target.left) + float(target.right)) * 0.5
	var source_middle := (float(source.left) + float(source.right)) * 0.5
	var vertical := _surface_y(source, source_middle) - _surface_y(target, middle)
	var max_rise := _jump_speed * _jump_speed / (2.0 * GRAVITY) + _jump_speed * STEP * 0.5
	if vertical > max_rise * (2.35 if double_jump else 1.0) or absf(middle - source_middle) > _speed * 2.9 + (float(source.right) - float(source.left)) * 0.5:
		return candidates
	for launch_x in [clampf(middle, source.left, source.right), source_middle, float(source.left), float(source.right)]:
		for land_x in [lerpf(clampf(launch_x, target.left, target.right), middle, 0.15), float(target.left), float(target.right)]:
			for kind in (3 if double_jump else 2):
				if kind == 0 and vertical > 5.0:
					continue
				candidates.append({"from": from, "to": to, "launch": _surface_point(from, launch_x),
					"x": land_x, "jump": kind > 0, "double": kind == 2,
					"cost": absf(launch_x - source_middle) / _speed + (1.0 if kind == 2 else 0.0)})
	return candidates


func _routes(start: int) -> Dictionary:
	var costs: Dictionary = {start: 0.0}
	var first: Dictionary = {}
	var visited: Dictionary = {}
	for iteration in _surfaces.size():
		var current := -1
		var best := INF
		for index in costs:
			if not visited.has(index) and float(costs[index]) < best:
				current = index
				best = costs[index]
		if current < 0:
			break
		visited[current] = true
		for edge in _graph[current]:
			var next: int = edge.to
			var cost: float = best + edge.cost
			if cost < float(costs.get(next, INF)):
				costs[next] = cost
				first[next] = edge if current == start else first[current]
	return {"costs": costs, "first": first}


func _observe_people() -> void:
	for contact in _contacts.values():
		contact.visible = false
	var alive: Dictionary = {}
	for person in _people:
		if person.id == _participant_id or int(person.team) == int(_me.team) or int(person.health) <= 0 or int(person.hearts) <= 0:
			continue
		alive[person.id] = true
		if person.ability == "invisibility" and person.active:
			continue
		if not _visible(_position, person.position):
			continue
		var ready: float = _contacts[person.id].ready if _contacts.has(person.id) else _clock + _reaction * _rng.randf_range(0.85, 1.25)
		var contact: Dictionary = person.duplicate()
		contact.seen = _clock
		contact.ready = ready
		contact.visible = true
		_contacts[person.id] = contact
	for id in _contacts.keys():
		if not alive.has(id) or _clock - float(_contacts[id].seen) > MEMORY_SECONDS:
			_contacts.erase(id)


func _target() -> Dictionary:
	if not _contacts.has(_target_id):
		return {}
	var contact: Dictionary = _contacts[_target_id]
	if _clock - float(contact.seen) > MEMORY_SECONDS:
		return {}
	return contact


func _contact_position(contact: Dictionary) -> Vector2:
	# Brief extrapolation; never extrapolate an unseen player through the map.
	var elapsed := minf(_clock - float(contact.seen), 0.20) if contact.visible else 0.0
	return Vector2(contact.position) + Vector2(contact.velocity) * elapsed


func _choose_tactic() -> void:
	var best := -INF
	var selected := ""
	for id in _contacts:
		var contact: Dictionary = _contacts[id]
		if _clock < float(contact.ready) or _clock - float(contact.seen) > MEMORY_SECONDS:
			continue
		var score := -_position.distance_to(contact.position) + (180.0 if contact.visible else -300.0)
		score += (100.0 - float(contact.health)) * _aggression * 3.0
		if id == _target_id:
			score += 260.0
		for ally in _people:
			if ally.id != _participant_id and int(ally.team) == int(_me.team) and int(ally.health) > 0:
				score += maxf(0.0, 500.0 - Vector2(ally.position).distance_to(contact.position)) * _teamwork
		if score > best:
			best = score
			selected = id
	if selected != _target_id:
		_target_id = selected
		_melee_until = _clock
		_melee_decide_at = _clock
		_shoot_at = maxf(_shoot_at, _clock + _reaction)
		_plan_at = minf(_plan_at, _clock + 0.15)
	var target := _target()
	var previous := _tactic
	if target.is_empty():
		_tactic = Tactic.ROAM
	elif not target.visible:
		_tactic = Tactic.HUNT
	else:
		var armour: Armour = Data.ARMOUR.get(_me.armour)
		var resilience := 1.0 / maxf(0.2, armour.damage_multiplier) if armour != null else 1.0
		var life_margin := 8.0 if int(_me.hearts) == 1 else 0.0
		var vulnerable := float(_me.health) * resilience < 24.0 + (1.0 - _aggression) * 28.0 + life_margin
		# Current modes share elimination combat; their match clocks and snapshot
		# teams inform urgency/support without depending on a live mode node.
		var mode: Mode = Data.MODES.get(_mode_id)
		if mode != null and mode.time_limit_seconds > 0 and _clock > mode.time_limit_seconds - 12.0:
			vulnerable = false
		var empty := int(_me.melee_ammo) == 0 and int(_me.ranged_ammo) == 0
		var reload_ranged := int(_me.ranged_ammo) == 0 and _position.distance_to(target.position) > 420.0 and float(_me.ranged_reload) < 1.0
		var wants_retreat: bool = (vulnerable and float(target.health) > 25.0) or empty or reload_ranged
		if previous == Tactic.RETREAT and _clock < _retreat_until:
			_tactic = Tactic.RETREAT
		elif wants_retreat and _clock >= _retreat_again_at:
			_tactic = Tactic.RETREAT
			_retreat_until = _clock + _rng.randf_range(1.2, 2.4)
			_retreat_again_at = _retreat_until + _rng.randf_range(2.0, 4.0)
		else:
			_tactic = Tactic.ENGAGE
	if previous != _tactic:
		_plan_at = _clock
	_choose_melee_pressure(target)
	if _clock >= _strafe_at:
		# Brief pauses, but usually keep moving for a readable, active duel.
		_strafe = 0 if _rng.randf() < 0.12 else (-1 if _rng.randf() < 0.5 else 1)
		_strafe_at = _clock + _rng.randf_range(0.50, 1.10)


func _choose_melee_pressure(target: Dictionary) -> void:
	var melee: Melee = Data.MELEE.get(_me.melee)
	if target.is_empty() or _tactic != Tactic.ENGAGE or melee == null or int(_me.melee_ammo) <= 0:
		if _melee_until > _clock:
			_plan_at = _clock
		_melee_until = _clock
		return
	if _clock < _melee_decide_at:
		return
	# Hard bots start a committed rush from farther away and do so more often.
	# Even easy bots defend themselves with melee when already in hit range.
	var reach := melee.hitbox_size.x * lerpf(1.4, 3.0, _melee_aggression)
	var opportunity := _position.distance_to(_contact_position(target)) < reach
	if opportunity and _rng.randf() < _melee_aggression:
		_melee_until = _clock + _rng.randf_range(1.0, 1.8) + _melee_aggression * 0.6
		_plan_at = _clock
	_melee_decide_at = maxf(_clock + _rng.randf_range(0.8, 1.3), _melee_until)


func _preferred_range() -> float:
	var melee: Melee = Data.MELEE.get(_me.melee)
	var ranged: Ranged = Data.RANGED.get(_me.ranged)
	var melee_range := melee.hitbox_size.x * 0.70 if melee != null else 180.0
	if ranged == null or ranged.projectile == null or int(_me.ranged_ammo) <= 0:
		return melee_range
	var range := float(ranged.projectile.range) * 0.52 * _spacing
	if ranged.simultaneous_projectiles:
		range *= 0.8
	if ranged.projectile is Rocket:
		range = maxf(range, ranged.projectile.explosion_radius + 220.0)
	var target := _target()
	if not target.is_empty() and int(_me.melee_ammo) > 0 and _clock < _melee_until:
		range = melee_range
	return range


func _choose_destination() -> void:
	var current := _surface_at(_position, 35.0)
	if current < 0:
		return
	var routes := _routes(current)
	var target := _target()
	var best := -INF
	var chosen := current
	var destination := _position
	var preferred := _preferred_range()
	var target_position := _contact_position(target) if not target.is_empty() else _position
	for index in routes.costs:
		var s: Dictionary = _surfaces[index]
		var middle := (float(s.left) + float(s.right)) * 0.5
		var candidates: Array = [middle]
		if not target.is_empty():
			candidates.append(clampf(target_position.x - preferred, s.left, s.right))
			candidates.append(clampf(target_position.x + preferred, s.left, s.right))
			if _tactic == Tactic.HUNT:
				candidates.append(clampf(target_position.x, s.left, s.right))
		else:
			candidates.append(_rng.randf_range(s.left, s.right))
		for x in candidates:
			var point := _surface_point(index, x)
			var score := -float(routes.costs[index]) * 100.0 - absf(point.x - _position.x) * 0.08
			if target.is_empty():
				score += _rng.randf_range(0.0, 480.0)
				if point.distance_to(_position) < 180.0:
					score -= 250.0
			else:
				var distance := point.distance_to(target_position)
				var visible := _visible(point, target_position)
				match _tactic:
					Tactic.RETREAT:
						score += minf(distance, preferred + 450.0) * 0.65
						score += 230.0 if not visible else 0.0
					Tactic.HUNT:
						score -= distance * 0.6
					_:
						score -= absf(distance - preferred) * 0.65
						score += 260.0 if visible else -160.0
						score -= absf(point.y - target_position.y) * 0.12
				# Small stable preferences prevent perfect mirrored duels.
				score += _rng.randf_range(-35.0, 35.0)
				if index == _goal_surface:
					score += 45.0
			if score > best:
				best = score
				chosen = index
				destination = point
	_goal = destination
	_goal_surface = chosen
	_edge = routes.first.get(chosen, {}).duplicate()


func _move(input: ParticipantInput) -> void:
	var current := _surface_at(_position, 30.0)
	if _flight:
		_left_floor = _left_floor or not _grounded
		input.direction = _steer(_position, _velocity, float(_edge.get("x", _goal.x)))
		if (_grounded and _left_floor and _clock - _flight_at > 0.18) or _clock - _flight_at > 3.0:
			_flight = false
			_edge = {}
			_plan_at = _clock
		else:
			return
	if _grounded and current < 0:
		# The real capsule can land on the fringe outside our safe route margin.
		# Step inward instead of repeatedly searching for an airborne recovery.
		for index in _surfaces.size():
			var inside := _surface_point(index, _position.x)
			if absf(inside.y - _position.y) < 30.0 and absf(inside.x - _position.x) < RADIUS + 32.0:
				input.direction = _steer(_position, _velocity, inside.x)
				return
	if not _grounded or current < 0:
		_recover_air(input)
		return
	if not _edge.is_empty() and int(_edge.from) == current:
		var launch: Vector2 = _edge.launch
		input.direction = _steer(_position, _velocity, launch.x)
		if absf(_position.x - launch.x) < 24.0 and absf(_velocity.x) < 180.0 and _clock >= _jump_at:
			var landing := _simulate(_position, _velocity, _edge.x, _edge.jump, _edge.double)
			if not landing.is_empty() and int(landing.surface) == int(_edge.to):
				input.jumping = _edge.jump
				input.direction = _steer(_position, _velocity, _edge.x)
				_flight = true
				_flight_at = _clock
				_left_floor = bool(_edge.jump)
				_double_used = false
				_jump_at = _clock + 0.6
			else:
				if absf(_position.x - launch.x) > 3.0:
					# Braking may stop a few pixels short of a tight launch window.
					input.direction = int(signf(launch.x - _position.x))
				else:
					_edge = {}
					_plan_at = _clock + 0.25
		return
	var s: Dictionary = _surfaces[current]
	var desired_x := clampf(_goal.x, s.left, s.right)
	var target := _target()
	if not target.is_empty() and target.visible and _tactic == Tactic.ENGAGE:
		var offset := _contact_position(target) - _position
		var range := _preferred_range()
		if _clock < _melee_until:
			desired_x = clampf(_position.x + offset.x - signf(offset.x) * range, s.left, s.right)
		elif absf(absf(offset.x) - range) < 150.0 and absf(offset.y) < 220.0:
			desired_x = clampf(_position.x + _strafe * 220.0, s.left, s.right)
			if _strafe != 0 and absf(desired_x - _position.x) < 35.0:
				_strafe = -_strafe
				desired_x = clampf(_position.x + _strafe * 220.0, s.left, s.right)
	input.direction = _steer(_position, _velocity, desired_x)
	if _stuck > 0.65:
		# Reposition before retrying instead of endlessly jumping into a wall.
		_recover_until = _clock + 0.45
		_recover_x = clampf(_position.x - _last_direction * 160.0, s.left, s.right)
		_stuck = 0.0
		_edge = {}
		_plan_at = _recover_until
	if _clock < _recover_until:
		input.direction = _steer(_position, _velocity, _recover_x)
	var dodge := not _danger.is_empty()
	var hop := _hop_requested
	_hop_requested = false
	if (dodge or hop) and _clock >= _jump_at:
		var escape_x := clampf(_position.x + (input.direction if input.direction != 0 else _strafe) * 220.0, s.left, s.right)
		var landing := _simulate(_position, _velocity, escape_x, true)
		if not landing.is_empty():
			input.jumping = true
			_edge = {"x": escape_x, "double": false}
			_flight = true
			_flight_at = _clock
			_left_floor = true
			_jump_at = _clock + _rng.randf_range(1.1, 2.3)
		elif dodge:
			input.direction = _steer(_position, _velocity, clampf(_position.x - signf(float(_danger.x)) * 140.0, s.left, s.right))


func _recover_air(input: ParticipantInput) -> void:
	if _clock < _air_plan_at:
		input.direction = _steer(_position, _velocity, _air_x)
		return
	_air_plan_at = _clock + 0.18
	# Evaluate real landing trajectories from the observed velocity. This also
	# handles being knocked off a route without pretending another jump exists.
	var best := INF
	var chosen := _position.x
	for s in _surfaces:
		var x := clampf(_position.x, s.left, s.right)
		var landing := _simulate(_position, _velocity, x, false)
		if landing.is_empty():
			continue
		var score := absf(x - _position.x) + Vector2(landing.position).distance_to(_goal) * 0.12
		if score < best:
			best = score
			chosen = x
	if best != INF:
		input.direction = _steer(_position, _velocity, chosen)
		_goal.x = chosen
	else:
		# A recovery double jump may make one of these surfaces reachable.
		var nearest := INF
		for s in _surfaces:
			var x := clampf(_position.x, s.left, s.right)
			var distance := absf(x - _position.x)
			if distance < nearest:
				nearest = distance
				chosen = x
		input.direction = _steer(_position, _velocity, chosen)
		_goal.x = chosen

	_air_x = chosen


func _incoming_threat() -> Dictionary:
	var best_time := INF
	var result: Dictionary = {}
	for bullet in _bullets:
		if _clock - float(bullet.seen) < _reaction * 0.6:
			continue
		var position: Vector2 = bullet.position + bullet.velocity * minf(_clock - _snapshot_at, 0.15)
		var relative := position - _position
		var velocity: Vector2 = bullet.velocity - _velocity
		if velocity.length_squared() < 1.0:
			continue
		var time := -relative.dot(velocity) / velocity.length_squared()
		if time < 0.04 or time > 0.65 or time >= best_time:
			continue
		var closest := relative + velocity * time
		var ranged: Ranged = Data.RANGED.get(bullet.weapon)
		var margin := 40.0
		if ranged != null and ranged.projectile is Rocket:
			margin += ranged.projectile.explosion_radius * 0.45
		if absf(closest.x) < margin + 32.0 and absf(closest.y) < margin + 112.0 and _ray(position, position + Vector2(bullet.velocity) * time).is_empty():
			best_time = time
			result = {"time": time, "x": relative.x}
	return result


func _combat(input: ParticipantInput, dt: float) -> void:
	var target := _target()
	var melee: Melee = Data.MELEE.get(_me.melee)
	var ranged: Ranged = Data.RANGED.get(_me.ranged)
	input.current_weapon = 1 if int(_me.ranged_ammo) > 0 else 0
	if target.is_empty():
		input.aim_direction = _aim
		return
	var target_position := _contact_position(target)
	var origin := _position + PIVOT
	var aim_point := target_position + Vector2(0, -25)
	var distance := origin.distance_to(aim_point)
	var melee_range := melee.hitbox_size.x + 18.0 if melee != null else 0.0
	var use_melee := melee != null and int(_me.melee_ammo) > 0 and distance < melee_range
	if use_melee or ranged == null or int(_me.ranged_ammo) <= 0:
		input.current_weapon = 0
	if input.current_weapon == 1 and ranged.projectile != null and target.visible:
		var flight_time := _intercept_time(aim_point - origin, target.velocity, ranged.projectile.speed)
		# Imperfect tracking is correlated over decisions, not frame-by-frame noise.
		aim_point += Vector2(target.velocity) * minf(flight_time, 0.7) * _lead
		if ranged.projectile is Rocket and target.floor:
			aim_point.y += 50.0
	var desired := origin.direction_to(aim_point)
	if desired == Vector2.ZERO:
		desired = _aim
	var imperfect := desired.rotated(_aim_error)
	_aim = _aim.rotated(clampf(_aim.angle_to(imperfect), -_turn_speed * dt, _turn_speed * dt)).normalized()
	input.aim_direction = _aim
	if not target.visible or _clock < _shoot_at or _me.attacking:
		return
	var tolerance := atan2(65.0, maxf(distance, 1.0))
	if input.current_weapon == 0:
		if melee == null or int(_me.melee_ammo) <= 0 or not use_melee:
			return
		tolerance += atan2(melee.hitbox_size.y * 0.35, maxf(distance, 1.0))
		# Settle on the bot's imperfect estimate; waiting for the true direction
		# would erase easy-mode aim error by only permitting accurate shots.
		if absf(_aim.angle_to(imperfect)) > tolerance or not _visible(_position, target_position):
			return
		if melee.friendly_fire and _ally_in_line(origin, origin + _aim * melee.hitbox_size.x, melee.hitbox_size.y * 0.5):
			return
		input.attacking = true
		_shoot_at = _clock + melee.attack_duration + _rng.randf_range(0.06, 0.22)
	else:
		if ranged == null or ranged.projectile == null:
			return
		var offset := ranged.projectile_offset
		offset.y *= int(_me.facing)
		var muzzle := origin + offset.rotated(_aim.angle())
		var shot_distance := muzzle.distance_to(aim_point)
		if distance < ranged.projectile_offset.x + 35.0 or shot_distance > ranged.projectile.range * 0.94:
			return
		tolerance += deg_to_rad(ranged.spread_degrees) * 0.3
		if absf(_aim.angle_to(imperfect)) > tolerance or not _ray(origin, muzzle).is_empty():
			return
		var impact := muzzle + _aim * shot_distance
		var obstruction := _ray(muzzle, impact)
		if not obstruction.is_empty():
			impact = obstruction.position
			if not ranged.projectile is Rocket or impact.distance_to(target_position) > ranged.projectile.explosion_radius * 0.65:
				return
		if ranged.projectile is Rocket:
			var radius: float = ranged.projectile.explosion_radius + 70.0
			if _position.distance_to(impact) < radius:
				return
			for ally in _people:
				if int(ally.team) == int(_me.team) and int(ally.health) > 0 and Vector2(ally.position).distance_to(impact) < radius:
					return
		if ranged.projectile.friendly_fire and _ally_in_line(muzzle, impact, 55.0):
			return
		input.attacking = true
		# Bursts lock aim on the server, so wait for the entire burst to finish.
		_shoot_at = _clock + ranged.attack_duration + _rng.randf_range(0.07, 0.24)


func _intercept_time(offset: Vector2, velocity: Vector2, speed: float) -> float:
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(velocity)
	var c := offset.length_squared()
	if absf(a) < 0.001:
		return maxf(0.0, -c / b) if absf(b) > 0.001 else 0.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return 0.0
	var first := (-b - sqrt(discriminant)) / (2.0 * a)
	var second := (-b + sqrt(discriminant)) / (2.0 * a)
	if first > 0.0 and second > 0.0:
		return minf(first, second)
	return maxf(0.0, maxf(first, second))


func _ally_in_line(from: Vector2, to: Vector2, radius: float) -> bool:
	for ally in _people:
		if ally.id == _participant_id or int(ally.team) != int(_me.team) or int(ally.health) <= 0:
			continue
		var center: Vector2 = ally.position + Vector2(0, -25)
		if Geometry2D.get_closest_point_to_segment(center, from, to).distance_to(center) < radius + 65.0:
			return true
	return false


func _use_ability(input: ParticipantInput) -> void:
	if not _ability_ready():
		return
	var target := _target()
	var ability: Ability = Data.ABILITY.get(_me.ability)
	match String(_me.ability):
		"double_jump":
			if not _grounded and not _double_used and _velocity.y > -80.0:
				var planned := _flight and bool(_edge.get("double", false))
				var ordinary := _simulate(_position, _velocity, float(_edge.get("x", _goal.x)), false)
				var recovery := _simulate(_position, Vector2(_velocity.x, -_jump_speed * ability.jump_multiplier), float(_edge.get("x", _goal.x)), false)
				input.ability = planned or (ordinary.is_empty() and not recovery.is_empty())
				if input.ability:
					_double_used = true
		"dash":
			if input.direction != 0 and not _flight and (not _danger.is_empty() or _tactic == Tactic.RETREAT or (not target.is_empty() and _position.distance_to(target.position) > _preferred_range() + 400.0)):
				var end := _position + Vector2(input.direction * ability.distance, 0)
				var safe := true
				for step in range(1, 13):
					var point := _position.lerp(end, float(step) / 12.0)
					if not _body_clear(point) or _hazard_at(point):
						safe = false
						break
				input.ability = safe and _surface_at(end, 30.0) >= 0
		"invisibility":
			input.ability = not target.is_empty() and target.visible and (_tactic == Tactic.RETREAT or (_position.distance_to(target.position) < 750.0 and _aggression > 0.5) or _clock - _hurt_at < 0.6)
		"slam_down":
			if not _grounded and not target.is_empty() and target.visible:
				var target_position := _contact_position(target)
				var offset := target_position - _position
				var landing := _simulate(_position, Vector2(0, ability.speed), _position.x, false)
				input.ability = offset.y > 120.0 and offset.y < 620.0 and absf(offset.x) < 105.0 and not landing.is_empty() and Vector2(landing.position).distance_to(target_position) < 145.0
	if input.ability:
		_ability_at = _clock + 0.8
		if _me.ability == "dash" or _me.ability == "slam_down":
			_edge = {}
			_flight = false
			_plan_at = _clock + 0.2


func _predict(input: ParticipantInput, dt: float) -> void:
	var reset_vertical := input.jumping and _grounded
	if input.jumping and _grounded:
		_velocity.y = -_jump_speed
		_grounded = false
	if input.ability:
		var ability: Ability = Data.ABILITY.get(_me.ability)
		match String(_me.ability):
			"double_jump":
				_velocity.y = -_jump_speed * ability.jump_multiplier
				reset_vertical = true
			"dash":
				_position.x += input.direction * ability.distance
			"slam_down":
				_velocity = Vector2(0, ability.speed)
	var slamming: bool = _me.ability == "slam_down" and (input.ability or _me.active)
	if slamming:
		_velocity = Vector2(0, Data.ABILITY["slam_down"].speed)
	var remaining := dt
	while remaining > 0.0001:
		var step := minf(STEP, remaining)
		var motion := _motion(_position, _velocity, 0 if slamming else input.direction, step, not reset_vertical and not slamming)
		reset_vertical = false
		_position = motion.position
		_velocity = motion.velocity
		_grounded = int(motion.surface) >= 0
		remaining -= step
	if _grounded:
		_double_used = false
