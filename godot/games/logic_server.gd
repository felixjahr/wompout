extends Node

const SIMULATION_TICK_RATE := 30
const SNAPSHOT_FREQUENCY := 2

const MAX_RESEND_EVENTS := 3

const INPUT_BUFFER_SIZE := 128
const MAX_INPUT_LOOKBACK := 5

const PlayerServer := preload("res://player/player_server.tscn")
const BulletServer := preload("res://bullet/bullet_server.tscn")

var tick := 0

var bullet_counter := 0
var event_counter := 0

var players: Dictionary[String, CharacterBody2D] = {}
var bullets: Dictionary[String, Node2D] = {}
var events: Array[EventSnapshot] = []

var event_send_count: Dictionary[String, int] = {}

var player_ids: Array[String] = []

var inputs: Dictionary[String, Array] = {}
var last_jump_by_player: Dictionary[String, int]
var last_ability_by_player: Dictionary[String, int]
var last_attack_by_player: Dictionary[String, int]

var map: StaticBody2D

@onready var game_net := $"../../Net/GameNet"
@onready var map_container := $MapContainer
@onready var player_container := $PlayerContainer
@onready var bullet_container := $BulletContainer


func _ready() -> void:
	Engine.physics_ticks_per_second = SIMULATION_TICK_RATE
	game_net.connect("input_batch_received", _on_net_input_batch_received)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	tick += 1
	
	_tick_players(delta)
	_tick_bullets(delta)
	
	if tick % SNAPSHOT_FREQUENCY == 0:
		game_net.send_snapshot(_build_snapshot())


func spawn_map(map_id: String) -> void:
	var new_map := Data.MAPS[map_id].instantiate()
	map_container.add_child(new_map)
	map = new_map


func spawn_player(player_id: String, melee_id: String, ranged_id: String, armour_id: String, ability_id: String, hearts = null, ability_charge := 0) -> void:
	var new_player := PlayerServer.instantiate()
	new_player.player_id = player_id
	new_player.melee_id = melee_id
	new_player.ranged_id = ranged_id
	new_player.armour_id = armour_id
	new_player.ability_id = ability_id
	new_player.ability_charge = ability_charge
	if hearts:
		new_player.hearts = hearts
	if not player_id in player_ids:
		player_ids.append(player_id)
	new_player.global_position = map.spawn_points[player_ids.find(player_id)].global_position
	player_container.add_child(new_player)
	players[player_id] = new_player
	var input_buffer: Array[PlayerInput] = []
	input_buffer.resize(INPUT_BUFFER_SIZE)
	inputs[player_id] = input_buffer
	last_jump_by_player[player_id] = -1
	last_attack_by_player[player_id] = -1
	last_ability_by_player[player_id] = -1


func despawn_player(player_id: String) -> void:
	if not players.has(player_id):
		return
	players[player_id].queue_free()
	players.erase(player_id)
	inputs.erase(player_id)
	last_jump_by_player.erase(player_id)
	last_attack_by_player.erase(player_id)
	last_ability_by_player.erase(player_id)
	if players.size() == 1:
		_gameover()


func respawn_player(player_id: String) -> void:
	if not players.has(player_id):
		return
	var player = players[player_id]
	var hearts: int = player.hearts - 1
	if hearts <= 0:
		despawn_player(player_id)
		return
	
	var melee_id: String = player.melee_id
	var ranged_id: String = player.ranged_id
	var armour_id: String = player.armour_id
	var ability_id: String = player.ability_id
	var ability_charge: int = player.ability_charge
	
	players.erase(player_id)
	player.queue_free()
	
	spawn_player(player_id, melee_id, ranged_id, armour_id, ability_id, hearts, ability_charge)


func spawn_bullet(position: Vector2, speed: int, damage: int, self_hit: bool, range: int, direction: Vector2, player_id: String) -> void:
	var new_bullet := BulletServer.instantiate()
	new_bullet.bullet_id = str(bullet_counter)
	new_bullet.global_position = position
	new_bullet.speed = speed
	new_bullet.damage = damage
	new_bullet.self_hit = self_hit
	new_bullet.range = range
	new_bullet.direction = direction
	new_bullet.player_id = player_id
	bullet_container.add_child(new_bullet)
	bullets[new_bullet.bullet_id] = new_bullet
	bullet_counter += 1


func despawn_bullet(bullet_id: String) -> void:
	if not bullets.has(bullet_id):
		return
	bullets[bullet_id].queue_free()
	bullets.erase(bullet_id)


func spawn_event(event: EventSnapshot) -> void:
	event.event_id = str(event_counter)
	event_send_count[event.event_id] = 0
	event_counter += 1
	events.append(event)


func record_damage(attacker_player_id: String, damage: int) -> void:
	if not players.has(attacker_player_id):
		return
	players[attacker_player_id].ability_charge += damage


func _gameover() -> void:
	var ranking: Array[String] = players.keys()
	ranking.sort_custom(func(a, b): 
		if players[a].hearts == players[b].hearts:
			return players[a].health > players[b].health
		else:
			return players[a].hearts > players[b].hearts
	)
	get_parent().gameover(ranking)


func _tick_players(delta: float) -> void:
	for player_id in players.keys():
		var player := players[player_id]
		var input := _get_latest_input(player_id)
		player.tick(delta, input)


func _get_latest_input(player_id: String) -> PlayerInput:
	var result := PlayerInput.new()
	result.tick = tick
	
	for offset in MAX_INPUT_LOOKBACK:
		var wanted_tick := tick - offset
		var stored_input: PlayerInput = inputs[player_id][wanted_tick % INPUT_BUFFER_SIZE]
		if stored_input != null and stored_input.tick == wanted_tick:
			result.direction = stored_input.direction
			result.aim_direction = stored_input.aim_direction
			result.current_weapon = stored_input.current_weapon
			break
	
	for offset in MAX_INPUT_LOOKBACK:
		var wanted_tick := tick - offset
		var stored_input: PlayerInput = inputs[player_id][wanted_tick % INPUT_BUFFER_SIZE]
		if stored_input != null and stored_input.tick == wanted_tick:
			if stored_input.jumping and wanted_tick > last_jump_by_player[player_id]:
				result.jumping = true
				last_jump_by_player[player_id] = wanted_tick
			if stored_input.ability and wanted_tick > last_ability_by_player[player_id]:
				result.ability = true
				result.direction = stored_input.direction
				last_ability_by_player[player_id] = wanted_tick
			if stored_input.attacking and wanted_tick > last_attack_by_player[player_id]:
				result.attacking = true
				result.aim_direction = stored_input.aim_direction
				result.current_weapon = stored_input.current_weapon
				last_attack_by_player[player_id] = wanted_tick
	
	return result


func _tick_bullets(delta: float) -> void:
	for bullet in bullets.values():
		bullet.tick(delta)


func _build_snapshot() -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.tick = tick
	for player_id in players.keys():
		snapshot.players.append(_build_player_snapshot(player_id))
	for bullet_id in bullets.keys():
		snapshot.bullets.append(_build_bullet_snapshot(bullet_id))
	snapshot.events = events.duplicate()
	for event in snapshot.events:
		event_send_count[event.event_id] += 1
		if event_send_count[event.event_id] >= MAX_RESEND_EVENTS:
			events.erase(event)
			event_send_count.erase(event.event_id)
	return snapshot


func _build_player_snapshot(player_id: String) -> PlayerSnapshot:
	var player: CharacterBody2D = players[player_id]
	var player_snapshot := PlayerSnapshot.new()
	player_snapshot.player_id = player_id
	player_snapshot.position = player.global_position
	player_snapshot.velocity = player.velocity
	player_snapshot.health = player.health
	player_snapshot.hearts = player.hearts
	player_snapshot.facing = player.facing
	player_snapshot.is_on_floor = player.is_on_floor()
	player_snapshot.current_weapon = player.current_weapon
	player_snapshot.attacking = player.attacking
	player_snapshot.aim_direction = player.aim_direction
	player_snapshot.ability_active = player.ability_active
	player_snapshot.armour_id = player.armour_id
	player_snapshot.ability_id = player.ability_id
	player_snapshot.melee_id = player.melee_id
	player_snapshot.melee_ammunition = player.melee_ammunition
	player_snapshot.melee_recharge_time = player.melee_recharge_time
	player_snapshot.ranged_id = player.ranged_id
	player_snapshot.ranged_ammunition = player.ranged_ammunition
	player_snapshot.ranged_recharge_time = player.ranged_recharge_time
	player_snapshot.last_ability = player.last_ability
	player_snapshot.ability_charge = player.ability_charge
	return player_snapshot


func _build_bullet_snapshot(bullet_id: String) -> BulletSnapshot:
	var bullet: Node2D = bullets[bullet_id]
	var bullet_snapshot := BulletSnapshot.new()
	bullet_snapshot.bullet_id = bullet_id
	bullet_snapshot.position = bullet.global_position
	bullet_snapshot.speed = bullet.speed
	bullet_snapshot.direction = bullet.direction
	return bullet_snapshot


func _on_net_input_batch_received(player_id: String, input_batch: PlayerInputBatch) -> void:
	if not inputs.has(player_id):
		return
	for input in input_batch.inputs:
		var existing_input: PlayerInput = inputs[player_id][input.tick % INPUT_BUFFER_SIZE]
		if existing_input != null and existing_input.tick == input.tick:
			continue
		inputs[player_id][input.tick % INPUT_BUFFER_SIZE] = input
