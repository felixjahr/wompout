extends Node

const MODES: Dictionary[String, PackedScene] = {
	"solo_womp_ranked": preload("res://data/modes/womp/womp_server.tscn"),
	"duo_womp_ranked": preload("res://data/modes/womp/womp_server.tscn"),
	"super_womp_ranked": preload("res://data/modes/womp/womp_server.tscn"),
	"womp_draft_unranked": preload("res://data/modes/draft/draft_server.tscn"),
	"super_womp_unranked": preload("res://data/modes/womp/womp_server.tscn"),
}

const CONNECTION_TIMEOUT := 10
const SHUTDOWN_GRACE_SECONDS := 2.0

var game_id: String
var mode_id: String
var map_id: String
var participant_names: Dictionary = {}

var connection_deadlines: Dictionary[String, float] = {}
var known_players: Dictionary[String, bool] = {}
var match_ending := false
var pending_result_reports := 0
var result_report_failed := false

var game: Node

@onready var backend_net := $Net/BackendNet
@onready var game_net := $Net/GameNet


func _ready() -> void:
	var config: Dictionary = JSON.parse_string(
		OS.get_environment("SERVER_CONFIG")
	)
	
	game_id = config["gameId"]
	mode_id = config["modeId"]
	map_id = config["mapId"]
	
	var port: int = int(config["port"])
	
	var token_hashes: Dictionary = config["playerTokenHashes"]
	var allowed_players := {}
	for player_id in token_hashes:
		var token_hash: String = token_hashes[player_id]
		allowed_players[token_hash] = player_id
	
	backend_net.backend_url = config["backendUrl"]
	backend_net.callback_token = config["callbackToken"]
	
	game_net.allowed_players = allowed_players
	game_net.player_authenticated.connect(_on_net_player_authenticated)
	game_net.player_disconnected.connect(_on_net_player_disconnected)
	
	game = MODES[mode_id].instantiate()
	game.map_id = map_id
	game.players = config["players"]
	game.bots = config["bots"]
	game.results_ready.connect(_on_game_results_ready)
	game.gameover.connect(_on_game_gameover)
	add_child(game)
	
	for participant in game.players:
		participant_names[str(participant["id"])] = str(participant["displayName"])
	for participant in game.bots:
		participant_names[str(participant["id"])] = str(participant["displayName"])
	
	if not game_net.create_server(port):
		push_error("Failed to create server")
		get_tree().quit(1)
		return
	
	if not await backend_net.mark_ready(game_id):
		push_error("Failed to notify backend that room started")
		get_tree().quit(1)
		return
	
	var deadline := Time.get_ticks_msec() / 1000.0 + CONNECTION_TIMEOUT
	for player in game.players:
		var player_id := str(player["id"])
		if not known_players.has(player_id):
			connection_deadlines[player_id] = deadline


func _process(_delta: float) -> void:
	if match_ending:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for player_id in connection_deadlines.keys():
		if now < connection_deadlines[player_id]:
			continue
		
		connection_deadlines.erase(player_id)
		known_players.erase(player_id)
		
		for token_hash in game_net.allowed_players.keys():
			if game_net.allowed_players[token_hash] == player_id:
				game_net.allowed_players.erase(token_hash)

		game.player_abandoned(player_id)

		if match_ending:
			return


func _on_net_player_authenticated(player_id: String) -> void:
	connection_deadlines.erase(player_id)
	
	var player_was_known := known_players.has(player_id)
	known_players[player_id] = true
	
	game_net.send_init(player_id, mode_id, map_id, participant_names)
	
	if player_was_known:
		game.player_reconnected(player_id)
	else:
		game.player_received(player_id)


func _on_net_player_disconnected(player_id: String) -> void:
	if not known_players.has(player_id):
		return
	var deadline := Time.get_ticks_msec() / 1000.0 + CONNECTION_TIMEOUT
	connection_deadlines[player_id] = deadline


func _on_game_results_ready(results: Array) -> void:
	pending_result_reports += 1

	var reported: bool = await backend_net.report_results(
		game_id,
		results
	)

	if not reported:
		result_report_failed = true
		push_error("Failed to report team results.")

	pending_result_reports -= 1


func _on_game_gameover() -> void:
	if match_ending:
		return
	match_ending = true

	while pending_result_reports > 0:
		await get_tree().process_frame

	if result_report_failed:
		push_error("Cannot complete the match: some results were not delivered.")
		get_tree().quit(1)
		return

	var ended: bool = await backend_net.end_game(game_id)
	if not ended:
		push_error("Failed to close the match on the backend.")

	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0 if ended else 1)
