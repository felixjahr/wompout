extends Node

enum ClientState {
	LOADING,
	AUTH,
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
}

const STARTUP_RESOURCES: Array[String] = [
	"player",
	"lobby",
	"lobbyInvites",
	"match",
]

const Loading := preload("res://ui/loading/loading.tscn")
const Auth := preload("res://ui/auth/auth.tscn")
const Lobby := preload("res://ui/lobby/lobby.tscn")
const Gameover := preload("res://ui/gameover/gameover.tscn")

var state := ClientState.LOADING

var lobby: Dictionary = {}
var player: Dictionary = {}
var lobby_invites = []
var current_match = null

var startup_request_id := ""
var connected_game_id := ""
var displayed_game_id := ""

var pending_friend_invites := []

var ui: Node
var game: Node

@onready var backend_net := $Net/BackendNet
@onready var game_net := $Net/GameNet
@onready var ui_container := $UIContainer
@onready var game_container := $AspectRatioContainer/SubViewportContainer/GameContainer
@onready var error_popup := %ErrorPopup
@onready var share := %Share
@onready var deeplink := %Deeplink


func _ready() -> void:
	if OS.has_feature("ios") or OS.has_feature("android"):
		deeplink.initialize()
	_enter_state()


func show_error(message: String) -> void:
	error_popup.show_error(message)


func _change_state(new_state: ClientState, data = null) -> void:
	if state == new_state:
		return
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
	match state:
		ClientState.LOADING:
			game_net.disconnect_from_server()
			backend_net.disconnect_websocket()
			ui = Loading.instantiate()
			ui_container.add_child(ui)
			ui.render_loading(false)
			_load_session()
		ClientState.AUTH:
			ui = Auth.instantiate()
			ui_container.add_child(ui)
			ui.create_guest_requested.connect(_on_auth_create_guest_requested)
			ui.start_signup_requested.connect(_on_auth_start_signup_requested)
			ui.verify_signup_requested.connect(_on_auth_verify_signup_requested)
			ui.start_login_requested.connect(_on_auth_start_login_requested)
			ui.verify_login_requested.connect(_on_auth_verify_login_requested)
		ClientState.LOBBY:
			ui = Lobby.instantiate()
			ui.local_player_id = player["id"]
			ui_container.add_child(ui)
			ui.render_player(player)
			ui.render_lobby(lobby)
			ui.render_lobby_invites(lobby_invites)
			ui.logout_requested.connect(_on_lobby_logout_requested)
			ui.start_link_requested.connect(_on_lobby_start_link_requested)
			ui.verify_link_requested.connect(_on_lobby_verify_link_requested)
			ui.invite_player_requested.connect(_on_lobby_invite_player_requested)
			ui.accept_invite_requested.connect(_on_lobby_accept_invite_requested)
			ui.decline_invite_requested.connect(_on_lobby_decline_invite_requested)
			ui.leave_lobby_requested.connect(_on_lobby_leave_lobby_requested)
			ui.update_mode_requested.connect(_on_lobby_update_mode_requested)
			ui.update_ready_requested.connect(_on_lobby_update_ready_requested)
			ui.update_loadout_requested.connect(_on_lobby_update_loadout_requested)
			ui.create_invite_requested.connect(_on_lobby_create_invite_requested)
			ui.resource_opened.connect(_on_lobby_resource_opened)
			ui.resource_closed.connect(_on_lobby_resource_closed)
		ClientState.MATCHMAKING:
			ui = Loading.instantiate()
			ui_container.add_child(ui)
			ui.render_loading(true)
		ClientState.GAME:
			game = MODES[data["mode_id"]].instantiate()
			game.map_id = data["map_id"]
			game.participant_names = data["participant_names"]
			game_container.add_child(game)
		ClientState.GAMEOVER:
			ui = Gameover.instantiate()
			ui_container.add_child(ui)
			ui.render_gameover(data, str(player["id"]))
			ui.continue_button.disabled = lobby.get("status", "") != "open"
			ui.continue_pressed.connect(_on_gameover_continue_pressed)


func _exit_state(data = null) -> void:
	if state == ClientState.GAME:
		game_net.disconnect_from_server()
	for child in ui_container.get_children():
		child.queue_free()
	ui = null
	for child in game_container.get_children():
		child.queue_free()
	game = null


func _load_session() -> void:
	var retry_delay := 1.0
	
	while state == ClientState.LOADING:
		ui.set_progress(6.0)
		player = {}
		lobby = {}
		lobby_invites = []
		current_match = null
		
		connected_game_id = ""
		displayed_game_id = ""
		startup_request_id = ""
		
		var auth_result = await backend_net.authenticate()
		
		if state != ClientState.LOADING:
			return
		
		if auth_result == backend_net.AuthResult.AUTH_REQUIRED:
			_change_state(ClientState.AUTH)
			return
		
		if auth_result == backend_net.AuthResult.SUCCEEDED:
			ui.set_progress(7.0)
			var connected: bool = await backend_net.connect_websocket()
			
			if state != ClientState.LOADING:
				return
			
			if connected:
				ui.set_progress(42.0)
				startup_request_id = "startup-%d" % Time.get_ticks_usec()
				
				var subscribed: bool = backend_net.subscribe_resources(STARTUP_RESOURCES, startup_request_id)
				if subscribed:
					ui.set_progress(69.0)
					var timeout := get_tree().create_timer(8.0)
					
					while (
						state == ClientState.LOADING
						and backend_net.websocket_authenticated
						and timeout.time_left > 0.0
					):
						await get_tree().process_frame
		
		if state != ClientState.LOADING:
			return
		
		startup_request_id = ""
		backend_net.disconnect_websocket()
		
		await get_tree().create_timer(retry_delay).timeout
		retry_delay = minf(retry_delay * 2.0, 5.0)


func _apply_match_state() -> void:
	if current_match == null:
		if state != ClientState.GAMEOVER:
			if lobby.get("status", "") == "open":
				_change_state(ClientState.LOBBY)
			else:
				_change_state(ClientState.MATCHMAKING)
		return
	
	var snapshot: Dictionary = current_match
	var game_id := str(snapshot["gameId"])
	
	match str(snapshot["status"]):
		"starting":
			_change_state(ClientState.MATCHMAKING)
		"ready":
			if connected_game_id == game_id:
				return
			_change_state(ClientState.MATCHMAKING)
			connected_game_id = game_id
			var connection: Dictionary = snapshot["connection"]
			game_net.create_client(int(connection["port"]), str(connection["ip"]), str(connection["playerToken"]))
		"completed":
			if displayed_game_id == game_id:
				return
			displayed_game_id = game_id
			connected_game_id = ""
			game_net.disconnect_from_server()
			_change_state(ClientState.GAMEOVER, snapshot)
			var response: Dictionary = await backend_net.matches_acknowledge_match(game_id)
			if not response.get("ok", false):
				push_error("Could not acknowledge the match result.")
		"failed":
			if displayed_game_id == game_id:
				return
			displayed_game_id = game_id
			connected_game_id = ""
			game_net.disconnect_from_server()
			if lobby.get("status", "") == "open":
				_change_state(ClientState.LOBBY)
			else:
				_change_state(ClientState.MATCHMAKING)
			var response: Dictionary = await backend_net.matches_acknowledge_match(game_id)
			if not response.get("ok", false):
				push_error("Could not acknowledge the match result.")


func _on_backend_net_subscribed(request_id: String, snapshots: Dictionary) -> void:
	if snapshots.has("friends"):
		_on_backend_net_friends_updated(snapshots["friends"])
	if snapshots.has("rankings"):
		_on_backend_net_rankings_updated(snapshots["rankings"])
	if snapshots.has("shop"):
		_on_backend_net_shop_updated(snapshots["shop"])
	
	if state != ClientState.LOADING:
		return
	if startup_request_id.is_empty() or request_id != startup_request_id:
		return
	for resource in STARTUP_RESOURCES:
		if not snapshots.has(resource):
			return
	
	ui.set_progress(100.0)
	player = snapshots["player"]
	lobby = snapshots["lobby"]
	lobby_invites = snapshots["lobbyInvites"]
	current_match = snapshots["match"]

	startup_request_id = ""
	_apply_match_state()
	_try_redeem_friend_invites()


func _on_backend_net_error(_request_id: String, message: String) -> void:
	push_error(message)


func _on_backend_net_player_updated(snapshot: Dictionary) -> void:
	player = snapshot
	if state == ClientState.LOBBY:
		ui.render_player(player)


func _on_backend_net_lobby_updated(snapshot: Dictionary) -> void:
	lobby = snapshot
	match state:
		ClientState.GAMEOVER:
			ui.continue_button.disabled = lobby.get("status", "") != "open"
		ClientState.LOBBY, ClientState.MATCHMAKING:
			_apply_match_state()
			if state == ClientState.LOBBY:
				ui.render_lobby(lobby)


func _on_backend_net_lobby_invites_updated(snapshot: Array) -> void:
	lobby_invites = snapshot
	if state == ClientState.LOBBY:
		ui.render_lobby_invites(lobby_invites)


func _on_backend_net_match_updated(snapshot: Variant) -> void:
	current_match = snapshot
	if state == ClientState.LOADING or state == ClientState.AUTH:
		return
	_apply_match_state()


func _on_backend_net_friends_updated(snapshot: Dictionary) -> void:
	if state == ClientState.LOBBY:
		ui.render_friends(snapshot)


func _on_backend_net_rankings_updated(snapshot: Dictionary) -> void:
	if state == ClientState.LOBBY:
		ui.render_rankings(snapshot)


func _on_backend_net_shop_updated(snapshot: Dictionary) -> void:
	if state == ClientState.LOBBY:
		ui.render_shop(snapshot)


func _on_backend_net_websocket_disconnected() -> void:
	_change_state(ClientState.LOADING)


func _on_game_net_init_received(mode_id: String, map_id: String, participant_names: Dictionary) -> void:
	if state != ClientState.MATCHMAKING:
		return
	_change_state(ClientState.GAME, {
		"mode_id": mode_id,
		"map_id": map_id,
		"participant_names": participant_names,
	})


func _on_game_net_connection_failed() -> void:
	_change_state(ClientState.LOADING)


func _on_deeplink_deeplink_received(url: DeeplinkUrl) -> void:
	if url.get_scheme() != "https" or url.get_host() != "link.wompout.com":
		return
	var path := url.get_path()
	var prefix := "/friends/invite/"
	if not path.begins_with(prefix):
		return
	var token := path.trim_prefix(prefix)
	if token.is_empty() or token.contains("/"):
		return
	if not pending_friend_invites.has(token):
		pending_friend_invites.append(token)
	_try_redeem_friend_invites()


func _try_redeem_friend_invites() -> void:
	while not pending_friend_invites.is_empty():
		if state == ClientState.LOADING or state == ClientState.AUTH:
			return

		var token: String = pending_friend_invites.pop_front()
		var response: Dictionary = await backend_net.friends_redeem_invite(token)

		if not response.get("ok", false):
			push_error("Couldn't accept invite. Open the link again to retry.")


func _on_auth_create_guest_requested(displayName: String) -> void:
	var response: Dictionary = await backend_net.auth_create_guest(displayName)
	if not response["ok"]:
		show_error("Couldn't create your account. Please try again.")
		return
	_change_state(ClientState.LOADING)


func _on_auth_start_signup_requested(displayName: String, email: String, on_completed: Callable) -> void:
	var response: Dictionary = await backend_net.auth_start_signup(displayName, email)
	on_completed.call(response["ok"])
	if not response["ok"]:
		show_error("Couldn't send your verification code. Please try again.")


func _on_auth_verify_signup_requested(email: String, code: String) -> void:
	var response: Dictionary = await backend_net.auth_verify_signup(email, code)
	if not response["ok"]:
		show_error("Couldn't complete signup. Check your code or request a new one.")
		return
	_change_state(ClientState.LOADING)


func _on_auth_start_login_requested(email: String, on_completed: Callable) -> void:
	var response: Dictionary = await backend_net.auth_start_login(email)
	on_completed.call(response["ok"])
	if not response["ok"]:
		show_error("Couldn't send your login code. Please try again.")
		return


func _on_auth_verify_login_requested(email: String, code: String) -> void:
	var response: Dictionary = await backend_net.auth_verify_login(email, code)
	if not response["ok"]:
		show_error("Couldn't log in. Check your code or request a new one.")
		return
	_change_state(ClientState.LOADING)


func _on_lobby_logout_requested() -> void:
	var response: Dictionary = await backend_net.sessions_logout()
	if not response.get("ok", false):
		show_error("Couldn't log out. Please try again.")
		return
	backend_net.disconnect_websocket()
	backend_net.clear_session()
	_change_state(ClientState.AUTH)


func _on_lobby_start_link_requested(email: String, on_completed: Callable) -> void:
	var response: Dictionary = await backend_net.auth_start_link(email)
	on_completed.call(response["ok"])
	if not response["ok"]:
		show_error("Couldn't send your verification code. Please try again.")
		return


func _on_lobby_verify_link_requested(email: String, code: String, on_completed: Callable) -> void:
	var response: Dictionary = await backend_net.auth_verify_link(email, code)
	on_completed.call(response["ok"])
	if not response["ok"]:
		show_error("Couldn't link your email. Check your code or request a new one.")
		return


func _on_lobby_invite_player_requested(player_id: String) -> void:
	var response: Dictionary = await backend_net.lobbies_invite_player(player_id)
	if not response.get("ok", false):
		show_error("Couldn't invite this player. Please try again.")


func _on_lobby_accept_invite_requested(invite_id: String) -> void:
	var response: Dictionary = await backend_net.lobbies_accept_invite(invite_id)
	if not response.get("ok", false):
		show_error("Couldn't accept this invite. Please try again.")


func _on_lobby_decline_invite_requested(invite_id: String) -> void:
	var response: Dictionary = await backend_net.lobbies_decline_invite(invite_id)
	if not response.get("ok", false):
		show_error("Couldn't decline this invite. Please try again.")


func _on_lobby_leave_lobby_requested() -> void:
	var response: Dictionary = await backend_net.lobbies_leave_lobby()
	if not response.get("ok", false):
		show_error("Couldn't leave the lobby. Please try again.")


func _on_lobby_update_mode_requested(mode_id: String) -> void:
	var response: Dictionary = await backend_net.lobbies_update_mode(mode_id)
	if not response.get("ok", false):
		show_error("Couldn't change the game mode. Please try again.")


func _on_lobby_update_ready_requested(ready: bool) -> void:
	var response: Dictionary = await backend_net.lobbies_update_ready(ready)
	if not response.get("ok", false):
		show_error("Couldn't update your ready status. Please try again.")


func _on_lobby_update_loadout_requested(loadout: Dictionary) -> void:
	var response: Dictionary = await backend_net.lobbies_update_loadout(loadout)
	if not response.get("ok", false):
		show_error("Couldn't save your loadout. Please try again.")


func _on_lobby_create_invite_requested() -> void:
	var response: Dictionary = await backend_net.friends_create_invite()
	if not response.get("ok", false):
		show_error("Couldn't create an invite link. Please try again.")
		return
	var message: String = "Click this link to add as friend in Wompout!\n" + response["data"]["invite_url"]
	share.share_text("Invite Friend", "", message)


func _on_lobby_resource_opened(resource: String) -> void:
	var resources: Array[String] = [resource]
	var request_id := "open-%s-%d" % [
		resource,
		Time.get_ticks_usec(),
	]
	if not backend_net.subscribe_resources(resources, request_id):
		show_error("Couldn't load this content. Please reopen it to try again.")


func _on_lobby_resource_closed(resource: String) -> void:
	var resources: Array[String] = [resource]
	var request_id := "close-%s-%d" % [
		resource,
		Time.get_ticks_usec(),
	]
	backend_net.unsubscribe_resources(resources, request_id)


func _on_gameover_continue_pressed() -> void:
	_change_state(ClientState.LOBBY)
