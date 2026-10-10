extends Node

signal participant_died(participant_id: String)

const SIMULATION_TICK_RATE := 30
const SNAPSHOT_FREQUENCY := 2
const INPUT_BUFFER_SIZE := 128
const MAX_INPUT_LOOKBACK := 5

const ParticipantServer := preload("res://participant/participant_server.tscn")
const BulletServer := preload("res://bullet/bullet_server.tscn")

var tick := 0

var participants: Dictionary[String, CharacterBody2D] = {}
var bot_controllers: Dictionary[String, BotController] = {}
var participant_teams: Dictionary = {}
var player_inputs: Dictionary[String, Array] = {}
var last_jump_by_player: Dictionary[String, int]
var last_ability_by_player: Dictionary[String, int]
var last_attack_by_player: Dictionary[String, int]

var bullets: Dictionary[String, Node2D] = {}
var bullet_counter := 0

var map: StaticBody2D

@onready var game_net := $"../../Net/GameNet"
@onready var map_container := $MapContainer
@onready var participant_container := $ParticipantContainer
@onready var bullet_container := $BulletContainer


func _ready() -> void:
	Engine.physics_ticks_per_second = SIMULATION_TICK_RATE
	game_net.input_batch_received.connect(_on_net_input_batch_received)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	tick += 1
	
	var bot_snapshot: Snapshot = null
	if not bot_controllers.is_empty():
		bot_snapshot = _build_snapshot()
	
	for participant_id in participants.keys():
		var participant := participants[participant_id]
		var input: ParticipantInput
		if bot_controllers.has(participant_id):
			input = bot_controllers[participant_id].get_input(participant_id, bot_snapshot, delta)
		else:
			input = _get_player_input(participant_id)
		input.tick = tick
		participant.tick(delta, input)
	
	for bullet in bullets.values():
		bullet.tick(delta)
	
	if tick % SNAPSHOT_FREQUENCY == 0:
		game_net.send_snapshot(_build_snapshot(), participant_teams)


func spawn_map(map_id: String) -> void:
	map = Data.MAPS[map_id].instantiate()
	map_container.add_child(map)


func spawn_participant(participant_id: String, is_bot: bool, loadout: Dictionary, spawn_position: Vector2, hearts: int) -> void:
	if participants.has(participant_id):
		push_error("Participant already exists: %s" % participant_id)
		return
	
	if is_bot:
		bot_controllers[participant_id] = BotController.new()
	else:
		var input_buffer: Array[ParticipantInput] = []
		input_buffer.resize(INPUT_BUFFER_SIZE)
		player_inputs[participant_id] = input_buffer
		last_jump_by_player[participant_id] = -1
		last_attack_by_player[participant_id] = -1
		last_ability_by_player[participant_id] = -1
	
	_create_participant(participant_id, loadout, spawn_position, hearts, 0)


func respawn_participant(participant_id: String, spawn_position: Vector2, hearts: int) -> void:
	if not participants.has(participant_id):
		return
	
	var participant := participants[participant_id]
	var loadout := {
		"meleeId": participant.melee_id,
		"rangedId": participant.ranged_id,
		"armourId": participant.armour_id,
		"abilityId": participant.ability_id,
		"styleId": participant.style_id,
	}
	var ability_charge: int = participant.ability_charge
	participant_container.remove_child(participant)
	participant.queue_free()
	
	if player_inputs.has(participant_id):
		player_inputs[participant_id].fill(null)
	
	_create_participant(participant_id, loadout, spawn_position, hearts, ability_charge)


func despawn_participant(participant_id: String) -> void:
	if not participants.has(participant_id):
		return
	
	var participant := participants[participant_id]
	participants.erase(participant_id)
	bot_controllers.erase(participant_id)
	player_inputs.erase(participant_id)
	last_jump_by_player.erase(participant_id)
	last_attack_by_player.erase(participant_id)
	last_ability_by_player.erase(participant_id)
	participant_container.remove_child(participant)
	participant.queue_free()


func spawn_bullet(position: Vector2, speed: int, damage: int, friendly_fire: bool, range: int, direction: Vector2, participant_id: String) -> void:
	var new_bullet := BulletServer.instantiate()
	new_bullet.bullet_id = str(bullet_counter)
	new_bullet.global_position = position
	new_bullet.speed = speed
	new_bullet.damage = damage
	new_bullet.friendly_fire = friendly_fire
	new_bullet.range = range
	new_bullet.direction = direction
	new_bullet.participant_id = participant_id
	bullet_container.add_child(new_bullet)
	bullets[new_bullet.bullet_id] = new_bullet
	bullet_counter += 1


func despawn_bullet(bullet_id: String) -> void:
	if not bullets.has(bullet_id):
		return
	bullets[bullet_id].queue_free()
	bullets.erase(bullet_id)


func report_event(event: EventSnapshot) -> void:
	game_net.queue_event(event)


func report_participant_died(participant_id: String) -> void:
	if not participants.has(participant_id):
		return
	if not participants[participant_id].dead:
		return
	participant_died.emit(participant_id)


func report_damage_dealt(participant_id: String, damage: int) -> void:
	if not participants.has(participant_id):
		return
	participants[participant_id].ability_charge += damage


func are_teammates(first_id: String, second_id: String) -> bool:
	if not participant_teams.has(first_id):
		return false
	if not participant_teams.has(second_id):
		return false

	return participant_teams[first_id] == participant_teams[second_id]


func can_hit(attacker_id: String, target_id: String, friendly_fire: bool) -> bool:
	if friendly_fire:
		return true
	if attacker_id == target_id:
		return false
	return not are_teammates(attacker_id, target_id)


func _create_participant(participant_id: String, loadout: Dictionary, spawn_position: Vector2, hearts: int, ability_charge: int) -> void:
	var participant := ParticipantServer.instantiate()
	participant.participant_id = participant_id
	participant.melee_id = loadout["meleeId"]
	participant.ranged_id = loadout["rangedId"]
	participant.armour_id = loadout["armourId"]
	participant.ability_id = loadout["abilityId"]
	participant.style_id = loadout["styleId"]
	participant.hearts = hearts
	participant.ability_charge = ability_charge
	participant.global_position = spawn_position
	participants[participant_id] = participant
	participant_container.add_child(participant)


func _get_player_input(participant_id: String) -> ParticipantInput:
	var result := ParticipantInput.new()
	result.tick = tick
	
	for offset in MAX_INPUT_LOOKBACK:
		var wanted_tick := tick - offset
		var stored_input: ParticipantInput = player_inputs[participant_id][wanted_tick % INPUT_BUFFER_SIZE]
		if stored_input == null or stored_input.tick != wanted_tick:
			continue
		result.direction = stored_input.direction
		result.aim_direction = stored_input.aim_direction
		result.current_weapon = stored_input.current_weapon
		break
	
	for offset in MAX_INPUT_LOOKBACK:
		var wanted_tick := tick - offset
		var stored_input: ParticipantInput = player_inputs[participant_id][wanted_tick % INPUT_BUFFER_SIZE]
		if stored_input == null or stored_input.tick != wanted_tick:
			continue
		if stored_input.jumping and wanted_tick > last_jump_by_player[participant_id]:
			result.jumping = true
			last_jump_by_player[participant_id] = wanted_tick
		if stored_input.ability and wanted_tick > last_ability_by_player[participant_id]:
			result.ability = true
			result.direction = stored_input.direction
			last_ability_by_player[participant_id] = wanted_tick
		if stored_input.attacking and wanted_tick > last_attack_by_player[participant_id]:
			result.attacking = true
			result.aim_direction = stored_input.aim_direction
			result.current_weapon = stored_input.current_weapon
			last_attack_by_player[participant_id] = wanted_tick

	return result


func _build_snapshot() -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.tick = tick
	
	for participant_id in participants.keys():
		snapshot.participants.append(_build_participant_snapshot(participant_id))
	
	for bullet_id in bullets.keys():
		snapshot.bullets.append(_build_bullet_snapshot(bullet_id))
	
	return snapshot


func _build_participant_snapshot(participant_id: String) -> ParticipantSnapshot:
	var participant := participants[participant_id]
	var participant_snapshot := ParticipantSnapshot.new()
	participant_snapshot.participant_id = participant_id
	participant_snapshot.team_id = participant_teams[participant_id]
	participant_snapshot.position = participant.global_position
	participant_snapshot.velocity = participant.velocity
	participant_snapshot.health = participant.health
	participant_snapshot.hearts = participant.hearts
	participant_snapshot.facing = participant.facing
	participant_snapshot.is_on_floor = participant.is_on_floor()
	participant_snapshot.current_weapon = participant.current_weapon
	participant_snapshot.attacking = participant.attacking
	participant_snapshot.aim_direction = participant.aim_direction
	participant_snapshot.ability_active = participant.ability_active
	participant_snapshot.armour_id = participant.armour_id
	participant_snapshot.ability_id = participant.ability_id
	participant_snapshot.melee_id = participant.melee_id
	participant_snapshot.melee_ammunition = participant.melee_ammunition
	participant_snapshot.melee_recharge_time = participant.melee_recharge_time
	participant_snapshot.ranged_id = participant.ranged_id
	participant_snapshot.ranged_ammunition = participant.ranged_ammunition
	participant_snapshot.ranged_recharge_time = participant.ranged_recharge_time
	participant_snapshot.style_id = participant.style_id
	participant_snapshot.last_ability = participant.last_ability
	participant_snapshot.ability_charge = participant.ability_charge
	return participant_snapshot


func _build_bullet_snapshot(bullet_id: String) -> BulletSnapshot:
	var bullet := bullets[bullet_id]
	var bullet_snapshot := BulletSnapshot.new()
	bullet_snapshot.bullet_id = bullet_id
	bullet_snapshot.position = bullet.global_position
	bullet_snapshot.speed = bullet.speed
	bullet_snapshot.direction = bullet.direction
	return bullet_snapshot


func _on_net_input_batch_received(participant_id: String, input_batch: ParticipantInputBatch) -> void:
	if not player_inputs.has(participant_id):
		return
	for input in input_batch.inputs:
		var existing_input: ParticipantInput = player_inputs[participant_id][input.tick % INPUT_BUFFER_SIZE]
		if existing_input != null and existing_input.tick == input.tick:
			continue
		player_inputs[participant_id][input.tick % INPUT_BUFFER_SIZE] = input
