extends Node

enum ClientState {
	LOADING,
	ACCOUNT_CREATION,
<<<<<<< HEAD
	LOBBY,
	MATCHMAKING,
	GAME,
	GAMEOVER,
}

const MODES: Dictionary[String, PackedScene] = {
	"solo_womp_ranked": preload("res://data/modes/womp/womp_client.tscn"),
	"duo_womp_ranked": preload("res://data/modes/womp/womp_client.tscn"),
	"super_womp_ranked": preload("res://data/modes/womp/womp_client.tscn"),
	"womp_draft_unranked": preload("res://data/modes/draft/draft_client.tscn"),
	"super_womp_unranked": preload("res://data/modes/womp/womp_client.tscn"),
=======
	HOME,
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
>>>>>>> origin/main
}

const Loading := preload("res://ui/loading/loading.tscn")
const AccountCreation := preload("res://ui/account_creation/account_creation.tscn")
<<<<<<< HEAD
const Lobby := preload("res://ui/lobby/lobby.tscn")
const Matchmaking := preload("res://ui/matchmaking/matchmaking.tscn")
const Gameover := preload("res://ui/gameover/gameover.tscn")

var state := ClientState.LOADING

var lobby: Dictionary = {}
var player: Dictionary = {}
var friends: Dictionary = {}

var pending_game_ready: Dictionary = {}
var pending_friend_invites: Array[String] = []

var ui: Node
var game: Node
=======
const Home := preload("res://ui/home/home.tscn")
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
>>>>>>> origin/main

@onready var auth_net := $Net/AuthNet
@onready var backend_net := $Net/BackendNet
@onready var game_net := $Net/GameNet
<<<<<<< HEAD
@onready var ui_container := $UIContainer
@onready var game_container := $AspectRatioContainer/SubViewportContainer/GameContainer


func _ready() -> void:
	backend_net.lobby_updated.connect(_on_backend_lobby_updated)
	backend_net.player_updated.connect(_on_backend_player_updated)
	backend_net.friends_updated.connect(_on_backend_friends_updated)
	backend_net.game_ready_received.connect(_on_backend_game_ready_received)
	backend_net.game_over_received.connect(_on_backend_game_over_received)
	backend_net.game_failed_received.connect(_on_backend_game_failed_received)
	backend_net.websocket_disconnected.connect(_on_backend_websocket_disconnected)
	game_net.init_received.connect(_on_game_net_init)
	game_net.connection_failed.connect(_on_game_connection_failed)
	_enter_state()


func _change_state(new_state: ClientState, data = null) -> void:
	if state == new_state:
		return
=======
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
>>>>>>> origin/main
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
<<<<<<< HEAD
	match state:
		ClientState.LOADING:
			game_net.disconnect_from_server()
			backend_net.disconnect_websocket()
			ui = Loading.instantiate()
			ui_container.add_child(ui)
			var retry_delay := 1.0
			while state == ClientState.LOADING:
				player = {}
				lobby = {}
				friends = {}
				pending_game_ready = {}
				var auth_result = await auth_net.authenticate()
				if state != ClientState.LOADING:
					return
				if auth_result == auth_net.AuthResult.ACCOUNT_REQUIRED:
					_change_state(ClientState.ACCOUNT_CREATION)
					return
				if auth_result == auth_net.AuthResult.SUCCEEDED:
					if await backend_net.connect_websocket():
						var timeout := get_tree().create_timer(8.0)
						while state == ClientState.LOADING and backend_net.websocket_authenticated and timeout.time_left > 0.0:
							await get_tree().process_frame
				if state != ClientState.LOADING:
					return
				backend_net.disconnect_websocket()
				await get_tree().create_timer(retry_delay).timeout
				retry_delay = minf(retry_delay * 2.0, 5.0)
		ClientState.ACCOUNT_CREATION:
			ui = AccountCreation.instantiate()
			ui_container.add_child(ui)
			ui.confirm_pressed.connect(_on_account_creation_confirm_pressed)
		ClientState.LOBBY:
			ui = Lobby.instantiate()
			ui_container.add_child(ui)
			ui.render_lobby(lobby, player, friends)
			ui.play_toggled.connect(_on_lobby_play_toggled)
			ui.mode_changed.connect(_on_lobby_mode_changed)
			ui.friend_invite_requested.connect(_on_lobby_friend_invite_requested)
			ui.player_invited.connect(_on_lobby_player_invited)
			ui.invite_accepted.connect(_on_lobby_invite_accepted)
		ClientState.MATCHMAKING:
			ui = Matchmaking.instantiate()
			ui_container.add_child(ui)
		ClientState.GAME:
			game = MODES[data["mode_id"]].instantiate()
			game.map_id = data["map_id"]
			for member in lobby.get("players", []):
				game.participant_names[str(member["id"])] = str(member["displayName"])
			game_container.add_child(game)
		ClientState.GAMEOVER:
			ui = Gameover.instantiate()
			ui_container.add_child(ui)
			ui.render_gameover(data, str(player["id"]))
			ui.continue_button.disabled = lobby.get("status", "") != "open"
			ui.continue_pressed.connect(_on_gameover_continue_pressed)
=======
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
		new_home.create_button.connect("pressed", _on_home_create_pressed)
		new_home.join_button.connect("pressed", _on_home_join_pressed)
		new_home.options_button.connect("pressed", _on_home_options_pressed)
		new_home.name_label.text = auth_net.player_name
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
>>>>>>> origin/main


func _exit_state(data = null) -> void:
	if state == ClientState.GAME:
<<<<<<< HEAD
		game_net.disconnect_from_server()
	for child in ui_container.get_children():
		child.queue_free()
	ui = null
	for child in game_container.get_children():
		child.queue_free()
	game = null


func _on_backend_lobby_updated(updated_lobby: Dictionary) -> void:
	lobby = updated_lobby
	match state:
		ClientState.LOADING:
			_try_finish_loading()
		ClientState.GAMEOVER:
			ui.continue_button.disabled = lobby.get("status", "") != "open"
		ClientState.LOBBY, ClientState.MATCHMAKING:
			match lobby.get("status", ""):
				"open":
					if state == ClientState.LOBBY:
						ui.render_lobby(lobby, player, friends)
					else:
						_change_state(ClientState.LOBBY)
				"matchmaking", "in-game":
					_change_state(ClientState.MATCHMAKING)


func _on_backend_player_updated(updated_player: Dictionary) -> void:
	player = updated_player
	match state:
		ClientState.LOADING:
			_try_finish_loading()
		ClientState.LOBBY:
			ui.render_lobby(lobby, player, friends)


func _on_backend_friends_updated(updated_friends: Dictionary) -> void:
	friends = updated_friends
	match state:
		ClientState.LOADING:
			_try_finish_loading()
		ClientState.LOBBY:
			ui.render_lobby(lobby, player, friends)


func _on_native_url_received(url: String) -> void:
	var prefix := "https://link.wompout.com/friends/invite/"
	if not url.begins_with(prefix):
		return

	var token := url.substr(prefix.length()).split("?")[0].split("#")[0]
	if token.is_empty() or token.contains("/"):
		return

	if not pending_friend_invites.has(token):
		pending_friend_invites.append(token)

	_try_redeem_friend_invites()


func _try_redeem_friend_invites() -> void:
	while not pending_friend_invites.is_empty():
		if state == ClientState.LOADING or state == ClientState.ACCOUNT_CREATION:
			return

		var token: String = pending_friend_invites.pop_front()
		var response: Dictionary = await backend_net.redeem_friend_invite(token)

		if not response.get("ok", false):
			push_error("Couldn't accept invite. Open the link again to retry.")


func _try_finish_loading() -> void:
	if state != ClientState.LOADING:
		return

	if player.is_empty() or lobby.is_empty() or friends.is_empty():
		return

	match lobby.get("status", ""):
		"open":
			_change_state(ClientState.LOBBY)
		"matchmaking", "in-game":
			_change_state(ClientState.MATCHMAKING)
	
	if not pending_game_ready.is_empty():
		var connection := pending_game_ready
		pending_game_ready = {}
		_on_backend_game_ready_received(
			str(connection["ip"]),
			int(connection["port"]),
			str(connection["player_token"])
		)
	
	_try_redeem_friend_invites()


func _on_backend_game_ready_received(ip: String, port: int, player_token: String) -> void:
	if state == ClientState.LOADING:
		pending_game_ready = {
			"ip": ip,
			"port": port,
			"player_token": player_token,
		}
	elif state == ClientState.MATCHMAKING:
		game_net.create_client(port, ip, player_token)


func _on_backend_game_over_received(data: Dictionary) -> void:
	if state != ClientState.GAME and state != ClientState.MATCHMAKING:
		return
	pending_game_ready = {}
	_change_state(ClientState.GAMEOVER, data)


func _on_backend_game_failed_received(reason: String) -> void:
	push_error("Game failed: " + reason)
	pending_game_ready = {}
	game_net.disconnect_from_server()
	if state == ClientState.LOADING:
		return
	_change_state(ClientState.MATCHMAKING)


func _on_backend_websocket_disconnected() -> void:
	_change_state(ClientState.LOADING)


func _on_game_net_init(mode_id: String, map_id: String) -> void:
	if state != ClientState.MATCHMAKING:
		return
	_change_state(ClientState.GAME, {
		"mode_id": mode_id,
		"map_id": map_id,
	})


func _on_game_connection_failed() -> void:
	_change_state(ClientState.LOADING)


func _on_gameover_continue_pressed() -> void:
	_change_state(ClientState.LOBBY)


func _on_lobby_play_toggled(toggled_on: bool) -> void:
	ui.play_button.disabled = true

	var response: Dictionary = await backend_net.set_lobby_ready(toggled_on)
	
	if state != ClientState.LOBBY:
		return

	ui.play_button.disabled = false

	if not response.get("ok", false):
		ui.play_button.set_pressed_no_signal(not toggled_on)


func _on_lobby_mode_changed(mode_id: String) -> void:
	backend_net.set_lobby_mode(mode_id)


func _on_lobby_friend_invite_requested() -> void:
	ui.add_friends_button.disabled = true
	var response: Dictionary = await backend_net.create_friend_invite()
	
	if state != ClientState.LOBBY:
		return
	
	ui.add_friends_button.disabled = false
	
	DisplayServer.clipboard_set(response["data"]["invite_url"])


func _on_lobby_player_invited(player_id: String) -> void:
	backend_net.invite_player(player_id)


func _on_lobby_invite_accepted(invite_id: String) -> void:
	backend_net.accept_lobby_invite(invite_id)


func _on_account_creation_confirm_pressed(displayName: String) -> void:
	ui.confirm_button.disabled = true
	if not await auth_net.create_account(displayName):
		ui.confirm_button.disabled = false
		return
	_change_state(ClientState.LOADING)
=======
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
	if state != ClientState.CREATE and state != ClientState.JOINING:
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
	if state == ClientState.CREATING or state == ClientState.CREATE or state == ClientState.JOINING or state == ClientState.CONNECTING:
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
>>>>>>> origin/main
