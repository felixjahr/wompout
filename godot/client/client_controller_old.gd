extends Node

enum ClientState {
	LOADING,
	ACCOUNT_CREATION,
	HOME,
	MATCHMAKING,
	OPTIONS,
	CREATING,
	CREATE,
	JOIN,
	JOINING,
	CONNECTING,
	GAME,
}

const GAMES: Dictionary[String, PackedScene] = {
	"draft": preload("res://games/draft/draft_client.tscn"),
}

const Loading := preload("res://ui/loading/loading.tscn")
const AccountCreation := preload("res://ui/account_creation/account_creation.tscn")
const Home := preload("res://ui/home/home.tscn")
const Matchmaking := preload("res://ui/matchmaking/matchmaking.tscn")
const Options := preload("res://ui/options/options.tscn")
const Create := preload("res://ui/create/create.tscn")
const Join := preload("res://ui/join/join.tscn")

const GAME_CONNECT_TIMEOUT := 2.0
const GAME_CONNECT_ATTEMPTS := 4
const GAME_INIT_TIMEOUT := 8.0
const GAME_RECONNECT_TIMEOUT := 9.0
const GAME_RECONNECT_RETRY_DELAY := 0.5

var state: ClientState

var game: Node
var _game_connect_completed := false
var _game_connect_succeeded := false
var _game_init_received := false
var _game_connection_data := {}
var _suppress_next_game_disconnect := false
var _connect_generation := 0
var _reconnect_generation := 0
var _state_sync_received := false
var _game_reconnect_enabled := false
var _created_room_code := ""

@onready var auth_net := $Net/AuthNet
@onready var backend_net := $Net/BackendNet
@onready var game_net := $Net/GameNet
@onready var ui := $UI


func _ready() -> void:
	auth_net.connect("authed", _on_net_authed)
	auth_net.connect("auth_failed", _on_net_auth_failed)
	auth_net.connect("account_required", _on_net_account_required)
	auth_net.connect("server_unavailable", _on_net_server_unavailable)
	backend_net.connect("room_code_received", _on_net_room_code_received)
	backend_net.connect("room_start_received", _on_net_room_start_received)
	backend_net.connect("room_failed_received", _on_net_room_failed_received)
	game_net.connect("init_received", _on_net_init_received)
	game_net.connect("state_sync_received", _on_net_state_sync_received)
	multiplayer.server_disconnected.connect(_on_game_server_disconnected)
	_enter_state(ClientState.LOADING)
	auth_net.authenticate()


func _change_state(new_state: ClientState, data = null) -> void:
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
	if state == ClientState.LOADING:
		var new_loading := Loading.instantiate()
		ui.add_child(new_loading)
	elif state == ClientState.ACCOUNT_CREATION:
		var new_account_creation := AccountCreation.instantiate()
		ui.add_child(new_account_creation)
		new_account_creation.confirm_button.connect("pressed", _on_account_creation_confirm_pressed)
	elif state == ClientState.HOME:
		var new_home := Home.instantiate()
		ui.add_child(new_home)
		new_home.play_button.connect("pressed", _on_home_play_pressed)
		new_home.create_button.connect("pressed", _on_home_create_pressed)
		new_home.join_button.connect("pressed", _on_home_join_pressed)
		new_home.options_button.connect("pressed", _on_home_options_pressed)
		new_home.name_label.text = auth_net.player_name
	elif state == ClientState.MATCHMAKING:
		var new_matchmaking := Matchmaking.instantiate()
		ui.add_child(new_matchmaking)
		backend_net.matchmake()
	elif state == ClientState.OPTIONS:
		var new_options := Options.instantiate()
		ui.add_child(new_options)
		new_options.back_button.connect("pressed", _on_options_back_pressed)
	elif state == ClientState.CREATING:
		var new_loading := Loading.instantiate()
		ui.add_child(new_loading)
		backend_net.create_room()
	elif state == ClientState.CREATE:
		var new_create := Create.instantiate()
		ui.add_child(new_create)
		new_create.code.text = data
		new_create.back_button.connect("pressed", _on_create_back_pressed)
	elif state == ClientState.JOIN:
		var new_join := Join.instantiate()
		ui.add_child(new_join)
		new_join.submit_button.connect("pressed", _on_join_submit_pressed)
		new_join.back_button.connect("pressed", _on_join_back_pressed)
	elif state == ClientState.JOINING:
		var new_loading := Loading.instantiate()
		ui.add_child(new_loading)
		backend_net.join_room(data)
	elif state == ClientState.CONNECTING:
		var new_loading := Loading.instantiate()
		ui.add_child(new_loading)
		_connect_generation += 1
		var connect_generation := _connect_generation
		var connected := await _connect_to_game_server(data)
		if state != ClientState.CONNECTING or connect_generation != _connect_generation:
			return
		if not connected:
			push_error("Failed to connect to game server")
			_game_connection_data = {}
			_game_reconnect_enabled = false
			_change_state(ClientState.HOME)
			return
		if not game_net.send_game_token(data["game_token"]):
			push_error("Failed to send game token")
			_disconnect_game_server_silently()
			_game_connection_data = {}
			_game_reconnect_enabled = false
			_change_state(ClientState.HOME)
			return
		_game_init_received = false
		var init_timeout := get_tree().create_timer(GAME_INIT_TIMEOUT)
		while state == ClientState.CONNECTING and connect_generation == _connect_generation and not _game_init_received and init_timeout.time_left > 0.0:
			await get_tree().process_frame
		if state == ClientState.CONNECTING and connect_generation == _connect_generation and not _game_init_received:
			push_error("Game server did not initialize client")
			_disconnect_game_server_silently()
			_game_connection_data = {}
			_game_reconnect_enabled = false
			_change_state(ClientState.HOME)
	elif state == ClientState.GAME:
		var new_game := GAMES[data["game_id"]].instantiate()
		new_game.map_id = data["map_id"]
		new_game.player_names = data["player_names"]
		$AspectRatioContainer/SubViewportContainer/Game.add_child(new_game)
		new_game.connect("ended", _on_game_ended)
		if new_game.has_signal("match_over"):
			new_game.connect("match_over", _on_game_match_over)
		game = new_game


func _exit_state(data = null) -> void:
	if state == ClientState.GAME:
		game.queue_free()
	for child in ui.get_children():
		child.queue_free()


func _on_net_authed() -> void:
	_change_state(ClientState.HOME)


func _on_net_auth_failed() -> void:
	_change_state(ClientState.ACCOUNT_CREATION)


func _on_net_account_required() -> void:
	_change_state(ClientState.ACCOUNT_CREATION)


func _on_net_server_unavailable() -> void:
	if state != ClientState.LOADING:
		_change_state(ClientState.LOADING)


func _on_account_creation_confirm_pressed() -> void:
	var account_creation = ui.get_child(0)
	account_creation.confirm_button.disabled = true
	if not await auth_net.create_account(account_creation.name_edit.text):
		account_creation.confirm_button.disabled = false
		return
	_change_state(ClientState.HOME)


func _on_home_play_pressed() -> void:
	_change_state(ClientState.MATCHMAKING)


func _on_home_options_pressed() -> void:
	_change_state(ClientState.OPTIONS)


func _on_options_back_pressed() -> void:
	_change_state(ClientState.HOME)


func _on_create_back_pressed() -> void:
	var room_code := _created_room_code
	_created_room_code = ""
	backend_net.leave_room(room_code)
	_change_state(ClientState.HOME)


func _on_join_back_pressed() -> void:
	_change_state(ClientState.HOME)


func _on_home_create_pressed() -> void:
	_created_room_code = ""
	_change_state(ClientState.CREATING)


func _on_net_room_code_received(code: String) -> void:
	_created_room_code = code
	_change_state(ClientState.CREATE, code)


func _on_home_join_pressed() -> void:
	_change_state(ClientState.JOIN)


func _on_join_submit_pressed() -> void:
	_change_state(ClientState.JOINING, ui.get_child(0).code.text)


func _on_net_room_start_received(port: int, ip: String, game_token: String, player_names: Dictionary) -> void:
	if state != ClientState.CREATE and state != ClientState.JOINING and state != ClientState.MATCHMAKING:
		return
	_created_room_code = ""
	if port <= 0 or ip.is_empty() or game_token.is_empty():
		push_error("Received invalid game server endpoint")
		_change_state(ClientState.HOME)
		return
	_game_connection_data = {
		"port" : port,
		"ip" : ip,
		"game_token" : game_token,
		"player_names" : player_names,
	}
	_game_reconnect_enabled = true
	_change_state(ClientState.CONNECTING, _game_connection_data)


func _on_net_room_failed_received() -> void:
	if (
			state == ClientState.MATCHMAKING
			or state == ClientState.CREATING 
			or state == ClientState.CREATE 
			or state == ClientState.JOINING 
			or state == ClientState.CONNECTING
	):
		_created_room_code = ""
		_disconnect_game_server_silently()
		_game_connection_data = {}
		_game_reconnect_enabled = false
		_change_state(ClientState.HOME)


func _on_net_init_received(game_id: String, map_id: String) -> void:
	_game_init_received = true
	if state != ClientState.CONNECTING:
		return
	if not GAMES.has(game_id):
		push_error("Received unknown game id")
		_disconnect_game_server_silently()
		_game_connection_data = {}
		_game_reconnect_enabled = false
		_change_state(ClientState.HOME)
		return
	_change_state(ClientState.GAME, {
		"game_id" : game_id,
		"map_id" : map_id,
		"player_names" : _game_connection_data.get("player_names", {}),
	})


func _on_game_ended() -> void:
	_disconnect_game_server_silently()
	_game_connection_data = {}
	_game_reconnect_enabled = false
	_change_state(ClientState.HOME)


func _on_game_match_over() -> void:
	_game_reconnect_enabled = false


func _on_game_server_disconnected() -> void:
	if _suppress_next_game_disconnect:
		_suppress_next_game_disconnect = false
		return
	if state == ClientState.GAME and not _game_reconnect_enabled:
		return
	if state == ClientState.GAME and not _game_connection_data.is_empty():
		_begin_game_reconnect()
	elif state == ClientState.CONNECTING and not _game_connection_data.is_empty():
		_game_connection_data["reconnect_until"] = Time.get_unix_time_from_system() + GAME_RECONNECT_TIMEOUT
		_change_state(ClientState.CONNECTING, _game_connection_data)
	elif state == ClientState.CONNECTING or state == ClientState.GAME:
		_change_state(ClientState.HOME)


func _begin_game_reconnect() -> void:
	_reconnect_generation += 1
	var reconnect_generation := _reconnect_generation
	_state_sync_received = false
	var loading := Loading.instantiate()
	ui.add_child(loading)
	var reconnect_data := _game_connection_data.duplicate()
	reconnect_data["reconnect_until"] = Time.get_unix_time_from_system() + GAME_RECONNECT_TIMEOUT
	var connected := await _connect_to_game_server(reconnect_data)
	if state != ClientState.GAME or reconnect_generation != _reconnect_generation:
		return
	if not connected:
		_game_connection_data = {}
		_game_reconnect_enabled = false
		_change_state(ClientState.HOME)
		return
	if not game_net.send_game_token(_game_connection_data["game_token"]):
		_game_connection_data = {}
		_game_reconnect_enabled = false
		_change_state(ClientState.HOME)
		return
	var state_sync_timeout := get_tree().create_timer(GAME_INIT_TIMEOUT)
	while state == ClientState.GAME and reconnect_generation == _reconnect_generation and not _state_sync_received and state_sync_timeout.time_left > 0.0:
		await get_tree().process_frame
	if state == ClientState.GAME and reconnect_generation == _reconnect_generation and not _state_sync_received:
		_game_connection_data = {}
		_game_reconnect_enabled = false
		_change_state(ClientState.HOME)


func _on_net_state_sync_received(_state_sync: StateSync) -> void:
	_state_sync_received = true


func _connect_to_game_server(data: Dictionary) -> bool:
	var port := int(data["port"])
	var ip := str(data["ip"])
	if data.has("reconnect_until"):
		while Time.get_unix_time_from_system() < float(data["reconnect_until"]):
			if await _try_connect_to_game_server(port, ip):
				data.erase("reconnect_until")
				return true
			_disconnect_game_server_silently()
			await get_tree().create_timer(GAME_RECONNECT_RETRY_DELAY).timeout
		data.erase("reconnect_until")
		return false
	for attempt in GAME_CONNECT_ATTEMPTS:
		if await _try_connect_to_game_server(port, ip):
			return true
		_disconnect_game_server_silently()
		if attempt < GAME_CONNECT_ATTEMPTS - 1:
			await get_tree().create_timer(0.25).timeout
	return false


func _try_connect_to_game_server(port: int, ip: String) -> bool:
	_game_connect_completed = false
	_game_connect_succeeded = false
	var timeout := get_tree().create_timer(GAME_CONNECT_TIMEOUT)
	multiplayer.connected_to_server.connect(_on_game_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_game_connection_failed, CONNECT_ONE_SHOT)
	game_net.create_client(port, ip)
	while not _game_connect_completed and timeout.time_left > 0.0:
		await get_tree().process_frame
	_disconnect_game_connect_signals()
	return _game_connect_succeeded


func _disconnect_game_server_silently() -> void:
	if multiplayer.multiplayer_peer:
		_suppress_next_game_disconnect = true
		call_deferred("_clear_suppressed_game_disconnect")
	game_net.disconnect_from_server()


func _clear_suppressed_game_disconnect() -> void:
	_suppress_next_game_disconnect = false


func _on_game_connected() -> void:
	_game_connect_completed = true
	_game_connect_succeeded = true


func _on_game_connection_failed() -> void:
	_game_connect_completed = true
	_game_connect_succeeded = false


func _disconnect_game_connect_signals() -> void:
	if multiplayer.connected_to_server.is_connected(_on_game_connected):
		multiplayer.connected_to_server.disconnect(_on_game_connected)
	if multiplayer.connection_failed.is_connected(_on_game_connection_failed):
		multiplayer.connection_failed.disconnect(_on_game_connection_failed)
