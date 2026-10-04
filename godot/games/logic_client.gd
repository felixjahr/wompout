extends Node

const SIMULATION_TICK_RATE := 30
const RENDER_TICK_RATE := 60
const INPUT_BATCH_FREQUENCY := 2

const INPUT_LEAD := 3
const MAX_RESEND_INPUTS := 3
const INTERPOLATION_DELAY_TICKS := 3

const CLOCK_SNAP_THRESHOLD_TICKS := 15.0
const CLOCK_CORRECTION_FACTOR := 0.2

const SNAPSHOT_BUFFER_SIZE := 128
const INPUT_BUFFER_SIZE := 128
const SEEN_EVENT_BUFFER_SIZE := 32

const PlayerClient := preload("res://player/player_client.tscn")
const BulletClient := preload("res://bullet/bullet_client.tscn")

var estimated_server_tick: float
var tick := 0

var last_snapshot_tick := -1
var received_first_snapshot := false

var players: Dictionary[String, Node2D] = {}
var bullets: Dictionary[String, Node2D] = {}

var snapshots: Array[Snapshot]
var inputs: Array[PlayerInput]
var seen_events: Array[String]
var seen_event_index := 0

var player_names: Dictionary = {}
var local_player_id := ""

var overlay: Control
var map: Node2D

@onready var auth_net := get_node("/root/Controller/Net/AuthNet")
@onready var game_net := get_node("/root/Controller/Net/GameNet")
@onready var map_container := $MapContainer
@onready var player_container := $PlayerContainer
@onready var bullet_container := $BulletContainer


func _ready() -> void:
	Engine.physics_ticks_per_second = RENDER_TICK_RATE
	local_player_id = auth_net.player_id
	snapshots.resize(SNAPSHOT_BUFFER_SIZE)
	inputs.resize(INPUT_BUFFER_SIZE)
	seen_events.resize(SEEN_EVENT_BUFFER_SIZE)
	game_net.connect("snapshot_received", _on_net_snapshot_received)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	estimated_server_tick += delta * SIMULATION_TICK_RATE
	tick += 1
	
	if tick % INPUT_BATCH_FREQUENCY == 0:
		var input: PlayerInput = overlay.poll()
		input.tick = int(estimated_server_tick) + INPUT_LEAD

		inputs[input.tick % INPUT_BUFFER_SIZE] = input
		game_net.send_input_batch(_build_input_batch(input.tick))
	
	_render_interpolated_snapshot()


func spawn_map(map_id: String) -> void:
	var new_map := Data.MAPS[map_id].instantiate()
	map_container.add_child(new_map)
	map = new_map


func _on_net_snapshot_received(snapshot: Snapshot) -> void:
	if snapshot.tick < last_snapshot_tick:
		return
	last_snapshot_tick = snapshot.tick
	snapshots[snapshot.tick % SNAPSHOT_BUFFER_SIZE] = snapshot
	
	if not received_first_snapshot:
		received_first_snapshot = true
		estimated_server_tick = snapshot.tick
		return
	
	var clock_error := float(snapshot.tick) - estimated_server_tick
	if absf(clock_error) > CLOCK_SNAP_THRESHOLD_TICKS:
		estimated_server_tick = snapshot.tick
	else:
		estimated_server_tick += clock_error * CLOCK_CORRECTION_FACTOR


func _build_input_batch(input_tick: int) -> PlayerInputBatch:
	var player_input_batch := PlayerInputBatch.new()

	for tick in range(input_tick - MAX_RESEND_INPUTS + 1, input_tick + 1):
		var input := inputs[tick % INPUT_BUFFER_SIZE]
		if input != null and input.tick == tick:
			player_input_batch.inputs.append(input)

	return player_input_batch


func _render_interpolated_snapshot() -> void:
	if not received_first_snapshot:
		return
	var render_tick := estimated_server_tick - INTERPOLATION_DELAY_TICKS
	var render_snapshot: Snapshot = _build_interpolated_snapshot(render_tick)
	if render_snapshot == null:
		return
	for player_snapshot in render_snapshot.players:
		if player_snapshot.player_id == local_player_id:
			overlay.apply_snapshot(player_snapshot)
			break
	_apply_entity_snapshots(
		players,
		render_snapshot.players,
		func(player_snapshot): return player_snapshot.player_id,
		func(player_id):
			var player = PlayerClient.instantiate()
			player.player_name = str(player_names.get(player_id, player_id))
			if player_id == local_player_id:
				player.local = true
				player.camera = map.camera
			player_container.add_child(player)
			return player
	)
	_apply_entity_snapshots(
		bullets,
		render_snapshot.bullets,
		func(bullet_snapshot): return bullet_snapshot.bullet_id,
		func(bullet_id):
			var bullet = BulletClient.instantiate()
			bullet_container.add_child(bullet)
			return bullet
	)
	
	for event in render_snapshot.events:
		if event.event_id in seen_events:
			continue
		seen_events[seen_event_index] = event.event_id
		seen_event_index = (seen_event_index + 1) % SEEN_EVENT_BUFFER_SIZE
		_apply_event(event)


func _build_interpolated_snapshot(render_tick: float) -> Snapshot:
	var older: Snapshot = null
	var newer: Snapshot = null
	for snapshot in snapshots:
		if snapshot == null:
			continue
		if snapshot.tick <= render_tick:
			if older == null or snapshot.tick > older.tick:
				older = snapshot
		if snapshot.tick >= render_tick:
			if newer == null or snapshot.tick < newer.tick:
				newer = snapshot

	if older == null and newer == null:
		return null
	if older == null:
		return newer
	if newer == null:
		return older
	if older.tick == newer.tick:
		return newer

	var alpha := inverse_lerp(float(older.tick), float(newer.tick), render_tick)
	return _interpolate_snapshots(older, newer, alpha)


func _interpolate_snapshots(older: Snapshot, newer: Snapshot, alpha: float) -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.players = []
	snapshot.bullets = []
	snapshot.events = older.events
	
	var older_players: Dictionary[String, PlayerSnapshot] = {}
	for player_snapshot in older.players:
		older_players[player_snapshot.player_id] = player_snapshot
	for newer_player in newer.players:
		if older_players.has(newer_player.player_id):
			snapshot.players.append(_interpolate_player_snapshot(older_players[newer_player.player_id], newer_player, alpha))
		else:
			snapshot.players.append(newer_player)

	var older_bullets: Dictionary[String, BulletSnapshot] = {}
	for bullet_snapshot in older.bullets:
		older_bullets[bullet_snapshot.bullet_id] = bullet_snapshot
	for newer_bullet in newer.bullets:
		if older_bullets.has(newer_bullet.bullet_id):
			snapshot.bullets.append(_interpolate_bullet_snapshot(older_bullets[newer_bullet.bullet_id], newer_bullet, alpha))
		else:
			snapshot.bullets.append(newer_bullet)
	return snapshot


func _interpolate_player_snapshot(older: PlayerSnapshot, newer: PlayerSnapshot, alpha: float) -> PlayerSnapshot:
	var snapshot := PlayerSnapshot.new()
	snapshot.player_id = newer.player_id
	snapshot.position = older.position.lerp(newer.position, alpha)
	snapshot.velocity = newer.velocity
	snapshot.health = newer.health
	snapshot.hearts = newer.hearts
	snapshot.facing = newer.facing
	snapshot.is_on_floor = newer.is_on_floor
	snapshot.current_weapon = newer.current_weapon
	snapshot.attacking = newer.attacking
	snapshot.aim_direction = newer.aim_direction
	snapshot.ability_active = newer.ability_active
	snapshot.armour_id = newer.armour_id
	snapshot.ability_id = newer.ability_id
	snapshot.melee_id = newer.melee_id
	snapshot.melee_ammunition = newer.melee_ammunition
	if older.melee_ammunition == newer.melee_ammunition:
		snapshot.melee_recharge_time = lerpf(older.melee_recharge_time, newer.melee_recharge_time, alpha)
	else:
		snapshot.melee_recharge_time = newer.melee_recharge_time
	snapshot.ranged_id = newer.ranged_id
	snapshot.ranged_ammunition = newer.ranged_ammunition
	if older.ranged_ammunition == newer.ranged_ammunition:
		snapshot.ranged_recharge_time = lerpf(older.ranged_recharge_time, newer.ranged_recharge_time, alpha)
	else:
		snapshot.ranged_recharge_time = newer.ranged_recharge_time
	snapshot.last_ability = newer.last_ability
	snapshot.ability_charge = newer.ability_charge
	return snapshot


func _interpolate_bullet_snapshot(older: BulletSnapshot, newer: BulletSnapshot, alpha: float) -> BulletSnapshot:
	var snapshot := BulletSnapshot.new()
	snapshot.bullet_id = newer.bullet_id
	snapshot.position = older.position.lerp(newer.position, alpha)
	snapshot.speed = newer.speed
	snapshot.direction = newer.direction
	return snapshot


func _apply_entity_snapshots(entities: Dictionary, entity_snapshots: Array, get_id: Callable, create_entity: Callable) -> void:
	var snapshot_ids := entity_snapshots.map(get_id)
	for id in entities.keys():
		if not snapshot_ids.has(id):
			entities[id].queue_free()
			entities.erase(id)
	for id in snapshot_ids:
		if not entities.has(id):
			var entity = create_entity.call(id)
			entities[id] = entity
	
	for entity_snapshot in entity_snapshots:
		var id: String = get_id.call(entity_snapshot)
		entities[id].apply_snapshot(entity_snapshot)


func _apply_event(event: EventSnapshot) -> void:
	if event is HitEventSnapshot:
		if not players.has(event.victim_player_id):
			return
		players[event.victim_player_id].apply_hit()
		match event.effect_id:
			"bullet":
				pass
