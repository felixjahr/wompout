extends Node

signal ended

enum GameState {
	DRAFT,
	FIGHT,
	GAMEOVER,
}

const DRAFT_TIME_LIMIT := 10.0
const AUTO_DRAFT_ANIMATION_SECONDS := 2.0

var state: GameState

var map_id: String

var draft_pool: Array[Dictionary]
var draft_options_by_player_id: Dictionary[String, Array] = {}
var draft_started_at_by_player_id: Dictionary[String, float] = {}
var draft_progress_by_player_id := {}
var draft_results := {}
var auto_draft_results := {}
var gameover_ranking: Array[String] = []
var fight_starting := false

@onready var backend_net := $"../Net/BackendNet"
@onready var game_net := $"../Net/GameNet"
@onready var logic := $Logic


func _ready() -> void:
	logic.spawn_map(map_id)
	game_net.connect("game_request_received", _on_net_game_request_received)
	_change_state(GameState.DRAFT)


func _process(_delta: float) -> void:
	if state != GameState.DRAFT or fight_starting:
		return
	var now := Time.get_unix_time_from_system()
	for player_id in draft_options_by_player_id.keys():
		if draft_results.has(player_id):
			continue
		if now - draft_started_at_by_player_id.get(player_id, now) >= DRAFT_TIME_LIMIT:
			_finalize_draft_for(player_id, draft_progress_by_player_id.get(player_id, []), true)


func player_received(player_id: String) -> void:
	var draft_options: Array[Dictionary] = []
	draft_options.append(draft_pool.pop_back())
	draft_options.append(draft_pool.pop_back())
	draft_options_by_player_id[player_id] = draft_options
	draft_started_at_by_player_id[player_id] = Time.get_unix_time_from_system()
	draft_progress_by_player_id[player_id] = []
	game_net.send_state_sync(player_id, _build_state_sync_for(player_id))


func player_reconnected(player_id: String) -> void:
	game_net.send_state_sync(player_id, _build_state_sync_for(player_id))


func player_abandoned(player_id: String) -> void:
	if state == GameState.DRAFT:
		var ranking: Array[String] = []
		for known_player_id in draft_options_by_player_id.keys():
			if known_player_id != player_id:
				ranking.append(known_player_id)
		gameover(ranking)
		return
	logic.despawn_player(player_id)


func gameover(ranking: Array[String]) -> void:
	gameover_ranking = ranking
	_change_state(GameState.GAMEOVER, ranking)


func _change_state(new_state: GameState, data = null) -> void:
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
	if state == GameState.DRAFT:
		draft_pool = _generate_draft_pool()
		fight_starting = false
	elif state == GameState.FIGHT:
		_resolve_draft_results()
	elif state == GameState.GAMEOVER:
		logic.set_physics_process(false)
		for player_id in draft_options_by_player_id.keys():
			game_net.send_state_sync(player_id, _build_state_sync_for(player_id))
		emit_signal("ended")


func _exit_state(data = null) -> void:
	pass


func _generate_draft_pool() -> Array[Dictionary]:
	var category_ids := [
		"melee",
		"ranged",
		"armour",
		"ability",
	]
	category_ids.shuffle()

	var remaining_ids_by_category := {}
	for category_id in category_ids:
		if remaining_ids_by_category.has(category_id):
			continue
		var ids: Array = Data.CATEGORIES[category_id].keys().duplicate()
		ids.shuffle()
		remaining_ids_by_category[category_id] = ids

	var pool: Array[Dictionary] = []
	for category_id in category_ids:
		var remaining_ids: Array = remaining_ids_by_category[category_id]
		var option_ids := [
			remaining_ids.pop_back(),
			remaining_ids.pop_back(),
		]
		pool.append({
			"category_id": category_id,
			"option_ids": option_ids,
		})
	return pool


func _resolve_draft_results() -> void:
	var player_ids := draft_results.keys()
	if player_ids.size() < 2:
		return
	var player_id_a: String = player_ids[0]
	var player_id_b: String = player_ids[1]
	
	var loadouts: Dictionary[String, Dictionary] = {
		player_id_a: {
			"melee_id": "",
			"ranged_id": "",
			"armour_id": "",
			"ability_id": "",
		},
		player_id_b: {
			"melee_id": "",
			"ranged_id": "",
			"armour_id": "",
			"ability_id": "",
		},
	}
	
	for player_id in player_ids:
		var other_player_id := player_id_b if player_id == player_id_a else player_id_a
		var draft_options: Array = draft_options_by_player_id[player_id].duplicate(true)
		var draft_result = draft_results[player_id]
		
		for pick in draft_result:
			if pick < 0 or pick > 1:
				pick = 0
			var other_pick = 0 if pick == 1 else 1
			var draft_option = draft_options.pop_front()
			var category_id = draft_option["category_id"]
			var option_ids = draft_option["option_ids"]
			loadouts[player_id][category_id + "_id"] = option_ids[pick]
			loadouts[other_player_id][category_id + "_id"] = option_ids[other_pick]
	
	for player_id in player_ids:
		logic.spawn_player(player_id, loadouts[player_id]["melee_id"], loadouts[player_id]["ranged_id"], loadouts[player_id]["armour_id"], loadouts[player_id]["ability_id"])
		logic.set_physics_process(true)
		game_net.send_state_sync(player_id, _build_state_sync_for(player_id))


func _build_state_sync_for(player_id: String) -> StateSync:
	var state_sync := StateSync.new()
	state_sync.phase = state
	var payload := {}
	match state:
		GameState.DRAFT:
			var started_at = draft_started_at_by_player_id.get(player_id, Time.get_unix_time_from_system())
			var elapsed = max(0.0, Time.get_unix_time_from_system() - started_at)
			payload = {
				"draft_options": draft_options_by_player_id.get(player_id, []),
				"draft_submitted": draft_results.has(player_id),
				"draft_picks": draft_results.get(player_id, draft_progress_by_player_id.get(player_id, [])),
				"draft_auto_picked": auto_draft_results.has(player_id),
				"draft_manual_pick_count": int(auto_draft_results.get(player_id, draft_progress_by_player_id.get(player_id, []).size())),
				"draft_time_limit": DRAFT_TIME_LIMIT,
				"draft_elapsed": min(DRAFT_TIME_LIMIT, elapsed),
			}
		GameState.GAMEOVER:
			payload = {
				"ranking": gameover_ranking,
			}
	state_sync.payload = payload
	return state_sync


func _on_net_game_request_received(player_id: String, game_request: GameRequest) -> void:
	if state != GameState.DRAFT:
		return
	if not draft_options_by_player_id.has(player_id):
		return
	if draft_results.has(player_id):
		game_net.send_state_sync(player_id, _build_state_sync_for(player_id))
		return
	match game_request.type:
		GameRequest.Type.DRAFT_PROGRESS:
			draft_progress_by_player_id[player_id] = _validated_picks(player_id, game_request.payload)
		GameRequest.Type.DRAFT_RESULT:
			_finalize_draft_for(player_id, game_request.payload, false)


func _validated_picks(player_id: String, raw_picks) -> Array[int]:
	var picks: Array[int] = []
	if not (raw_picks is Array):
		return picks
	var options_count = draft_options_by_player_id.get(player_id, []).size()
	var max_count = min(options_count, raw_picks.size())
	for i in max_count:
		var pick := int(raw_picks[i])
		picks.append(pick if pick == 0 or pick == 1 else 0)
	return picks


func _finalize_draft_for(player_id: String, raw_picks, fill_randomly: bool) -> void:
	if draft_results.has(player_id):
		return
	var picks := _validated_picks(player_id, raw_picks)
	var manual_pick_count := picks.size()
	var options_count := draft_options_by_player_id[player_id].size()
	while picks.size() < options_count:
		picks.append(randi_range(0, 1) if fill_randomly else 0)
	draft_progress_by_player_id[player_id] = picks
	draft_results[player_id] = picks
	if fill_randomly:
		auto_draft_results[player_id] = manual_pick_count
	game_net.send_state_sync(player_id, _build_state_sync_for(player_id))
	_try_start_fight(fill_randomly)


func _try_start_fight(delay_for_auto_draft: bool) -> void:
	if fight_starting or draft_results.size() < draft_options_by_player_id.size() or draft_options_by_player_id.size() < 2:
		return
	fight_starting = true
	if delay_for_auto_draft:
		await get_tree().create_timer(AUTO_DRAFT_ANIMATION_SECONDS).timeout
	if state == GameState.DRAFT:
		_change_state(GameState.FIGHT)
