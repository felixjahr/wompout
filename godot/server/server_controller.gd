extends Node

<<<<<<< HEAD
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

var connection_deadlines: Dictionary[String, float] = {}
=======
const GAMES: Dictionary[String, PackedScene] = {
	"draft": preload("res://games/draft/draft_server.tscn"),
}

const RECONNECT_TIMEOUT := 10
const SHUTDOWN_GRACE_SECONDS := 2.0

var game_id: String
var map_id: String
var code: String

var disconnected_players: Dictionary[String, float] = {}
>>>>>>> origin/main
var known_players: Dictionary[String, bool] = {}
var match_ending := false

var game: Node

@onready var backend_net := $Net/BackendNet
@onready var game_net := $Net/GameNet


func _ready() -> void:
<<<<<<< HEAD
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
	game.gameover.connect(_on_game_gameover)
	add_child(game)
	
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
=======
	var args := _get_cmdline_params()
	for key in ["port", "game_id", "map_id", "code", "allowed_players", "server_callback_secret"]:
		if not args.has(key) or str(args[key]).is_empty():
			push_error("Missing required server argument: %s" % key)
			get_tree().quit(1)
			return
	var port := int(args["port"])
	game_id = str(args["game_id"])
	map_id = str(args["map_id"])
	code = str(args["code"])
	backend_net.server_callback_secret = str(args["server_callback_secret"])
	if not GAMES.has(game_id):
		push_error("Unknown game id: %s" % game_id)
		get_tree().quit(1)
		return
	if not Data.MAPS.has(map_id):
		push_error("Unknown map id: %s" % map_id)
		get_tree().quit(1)
		return
	var parsed_allowed_players = JSON.parse_string(str(args["allowed_players"]))
	if not (parsed_allowed_players is Dictionary):
		push_error("Invalid allowed_players argument")
		get_tree().quit(1)
		return
	
	var new_game := GAMES[game_id].instantiate()
	new_game.map_id = map_id
	add_child(new_game)
	new_game.connect("ended", _on_game_ended)
	game = new_game
	
	game_net.allowed_players = parsed_allowed_players
	game_net.connect("player_authenticated", _on_net_player_authenticated)
	game_net.connect("player_disconnected", _on_net_player_disconnected)
	game_net.create_server(port)
	if not (await backend_net.start_room(code)):
		push_error("Failed to notify backend that room started")
		get_tree().quit(1)
>>>>>>> origin/main


func _process(_delta: float) -> void:
	if match_ending:
		return
<<<<<<< HEAD
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
	
	game_net.send_init(player_id, mode_id, map_id)
	
	if player_was_known:
		game.player_reconnected(player_id)
	else:
		game.player_received(player_id)
=======
	var now := Time.get_unix_time_from_system()
	var abandoned_player_id := ""
	var abandoned_at := INF
	for player_id in disconnected_players.keys():
		if now - disconnected_players[player_id] >= RECONNECT_TIMEOUT:
			if disconnected_players[player_id] < abandoned_at:
				abandoned_at = disconnected_players[player_id]
				abandoned_player_id = player_id
	if abandoned_player_id.is_empty():
		return
	disconnected_players.erase(abandoned_player_id)
	known_players.erase(abandoned_player_id)
	game.player_abandoned(abandoned_player_id)


func _on_net_player_authenticated(player_id: String) -> void:
	var player_was_known := known_players.has(player_id)
	known_players[player_id] = true
	if player_was_known:
		disconnected_players.erase(player_id)
		game_net.send_init(player_id, game_id, map_id)
		game.player_reconnected(player_id)
		return
	game_net.send_init(player_id, game_id, map_id)
	game.player_received(player_id)
>>>>>>> origin/main


func _on_net_player_disconnected(player_id: String) -> void:
	if not known_players.has(player_id):
		return
<<<<<<< HEAD
	var deadline := Time.get_ticks_msec() / 1000.0 + CONNECTION_TIMEOUT
	connection_deadlines[player_id] = deadline


func _on_game_gameover(results: Array) -> void:
	if match_ending:
		return
	match_ending = true
	
	var reported: bool = await backend_net.end_game(game_id, results)
	if not reported:
		push_error("Failed to report match completion to the backend.")
	
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0 if reported else 1)
=======
	disconnected_players[player_id] = Time.get_unix_time_from_system()


func _on_game_ended() -> void:
	if match_ending:
		return
	match_ending = true
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	await backend_net.end_room(code)
	get_tree().quit()


func _get_cmdline_params() -> Dictionary:
	var params := {}
	for arg in OS.get_cmdline_args():
		if "=" not in arg:
			continue
		var separator_index := arg.find("=")
		if separator_index <= 0:
			continue
		params[arg.substr(0, separator_index)] = arg.substr(separator_index + 1)
	return params
>>>>>>> origin/main
