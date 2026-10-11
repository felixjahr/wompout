class_name ModeServer
extends Node

signal results_ready(results: Array)
signal gameover

enum ModeState {
	PREPARING,
	FIGHT,
	GAMEOVER,
}

var state := ModeState.PREPARING

var map_id: String
var mode_id: String
var players: Array
var bots: Array

var remaining_ids: Array[String] = []
var spawn_positions: Dictionary[String, Vector2] = {}
var fight_end_tick: int

@onready var game_net := $"../Net/GameNet"
@onready var logic := $Logic


func _ready() -> void:
	logic.spawn_map(map_id)
	logic.set_physics_process(false)
	
	for participant in players:
		var participant_id := str(participant["id"])
		remaining_ids.append(participant_id)
		logic.participant_teams[participant_id] = participant["teamId"]

	for participant in bots:
		var participant_id := str(participant["id"])
		remaining_ids.append(participant_id)
		logic.participant_teams[participant_id] = participant["teamId"]
	
	game_net.game_request_received.connect(_on_net_game_request_received)
	
	_enter_state()


func player_received(player_id: String) -> void:
	_on_player_received(player_id)
	_sync_player(player_id)


func player_reconnected(player_id: String) -> void:
	_sync_player(player_id)


func player_abandoned(player_id: String) -> void:
	_on_participant_eliminated(player_id)


func _change_state(new_state: ModeState) -> void:
	_exit_state()
	state = new_state
	_enter_state()


func _enter_state() -> void:
	match state:
		ModeState.PREPARING:
			logic.set_physics_process(false)
			_enter_preparing()
		ModeState.FIGHT:
			_enter_fight()
			for player in players:
				if not remaining_ids.has(str(player["id"])):
					continue
				logic.spawn_participant(
						player["id"], 
						false, 
						_get_loadout(player["id"]), 
						_get_spawn_position(player["id"]), 
						_get_starting_hearts(player["id"]))
			for bot in bots:
				if not remaining_ids.has(str(bot["id"])):
					continue
				logic.spawn_participant(
						bot["id"],
						true,
						_get_loadout(bot["id"]),
						_get_spawn_position(bot["id"]), 
						_get_starting_hearts(bot["id"]))
			fight_end_tick = logic.tick + Data.MODES[mode_id].time_limit_seconds * logic.SIMULATION_TICK_RATE
			logic.set_physics_process(true)
		ModeState.GAMEOVER:
			logic.set_physics_process(false)
			_enter_gameover()
			gameover.emit()
	
	for player in players:
		_sync_player(player["id"])


func _sync_player(participant_id: String) -> void:
	var state_sync := StateSync.new()
	state_sync.phase = state
	state_sync.payload = _build_state_payload(participant_id)
	game_net.send_state_sync(participant_id, state_sync)


func _enter_preparing() -> void:
	pass


func _enter_fight() -> void:
	pass


func _enter_gameover() -> void:
	pass


func _exit_state() -> void:
	pass


func _on_player_received(_player_id: String) -> void:
	pass


func _on_time_limit_reached() -> void:
	var teams: Dictionary = {}

	for participant_id in remaining_ids:
		var team_id: int = int(logic.participant_teams[participant_id])

		if not teams.has(team_id):
			teams[team_id] = {
				"team_id": team_id,
				"hearts": 0,
				"health": 0,
			}

		var participant = logic.participants.get(participant_id)
		if participant == null:
			continue

		teams[team_id]["hearts"] += participant.hearts
		teams[team_id]["health"] += maxf(participant.health, 0.0)

	var ranked_teams: Array = teams.values()
	ranked_teams.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["hearts"] != b["hearts"]:
			return a["hearts"] > b["hearts"]
		return a["health"] > b["health"]
	)

	var results: Array[Dictionary] = []
	var placement := 1

	for i in range(ranked_teams.size()):
		var team: Dictionary = ranked_teams[i]

		if i > 0:
			var previous: Dictionary = ranked_teams[i - 1]
			if (
				team["hearts"] != previous["hearts"]
				or team["health"] != previous["health"]
			):
				placement = i + 1

		results.append_array(_finish_team(int(team["team_id"]), placement))

	results_ready.emit(results)
	_change_state(ModeState.GAMEOVER)


func _get_loadout(participant_id: String) -> Dictionary:
	for player in players:
		if player["id"] == participant_id:
			return player["loadout"]
	for bot in bots:
		if bot["id"] == participant_id:
			return bot["loadout"]
	return {}


func _get_spawn_position(participant_id: String) -> Vector2:
	if not spawn_positions.has(participant_id):
		spawn_positions[participant_id] = logic.map.spawn_points[spawn_positions.size()].global_position
	return spawn_positions[participant_id]


func _get_starting_hearts(_participant_id: String) -> int:
	return 3


func _on_logic_participant_died(participant_id: String) -> void:
	if state != ModeState.FIGHT:
		return
	var participant = logic.participants[participant_id]
	var hearts: int = participant.hearts - 1
	if hearts <= 0:
		_on_participant_eliminated(participant_id)
	else:
		logic.respawn_participant(
			participant_id,
			_get_spawn_position(participant_id),
			hearts
		)


func _on_participant_eliminated(participant_id: String) -> void:
	if state == ModeState.GAMEOVER:
		return
	if not remaining_ids.has(participant_id):
		return
	var team_id: int = int(logic.participant_teams[participant_id])
	if state == ModeState.FIGHT:
		logic.despawn_participant(participant_id)
	remaining_ids.erase(participant_id)
	var remaining_teams := _get_remaining_teams()
	if remaining_teams.has(team_id):
		return
	var team_results := _finish_team(team_id, remaining_teams.size() + 1)
	if remaining_teams.size() <= 1:
		for winner_team_id in remaining_teams:
			team_results.append_array(_finish_team(int(winner_team_id), 1))
		results_ready.emit(team_results)
		_change_state(ModeState.GAMEOVER)
	else:
		results_ready.emit(team_results)


func _on_logic_simulation_tick_finished() -> void:
	if state != ModeState.FIGHT:
		return
	if logic.tick >= fight_end_tick:
		_on_time_limit_reached()


func _build_state_payload(_participant_id: String) -> Dictionary:
	var payload: Dictionary = {}
	if state == ModeState.FIGHT:
		payload["fight_end_tick"] = fight_end_tick
	return payload


func _on_net_game_request_received(_player_id: String, _game_request: GameRequest) -> void:
	pass


func _get_remaining_teams() -> Dictionary:
	var teams: Dictionary = {}
	for participant_id in remaining_ids:
		var team_id: int = int(logic.participant_teams[participant_id])
		teams[team_id] = true
	return teams


func _finish_team(team_id: int, placement: int) -> Array[Dictionary]:
	var team_results: Array[Dictionary] = []
	for participant in players + bots:
		if int(participant["teamId"]) != team_id:
			continue
		var participant_id := str(participant["id"])
		var result := {
			"participantId": participant_id,
			"placement": placement,
			"loadout": _get_loadout(participant_id).duplicate(true),
		}
		team_results.append(result)
	return team_results
