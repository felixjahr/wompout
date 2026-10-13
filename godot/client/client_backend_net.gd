extends Node

signal subscribed(snapshots: Dictionary)
signal unsubscribed(resources: Array)
signal error(message: String)

signal player_updated(player: Dictionary)
signal lobby_updated(lobby: Dictionary)
signal lobby_invites_updated(invites: Array)
signal match_updated(snapshot: Variant)
signal friends_updated(friends: Dictionary)
signal rankings_updated(rankings: Dictionary)
signal shop_updated(shop: Dictionary)

signal session_refresh_finished(result: AuthResult)
signal websocket_disconnected

enum AuthResult {
	SUCCEEDED,
	AUTH_REQUIRED,
	SERVER_UNAVAILABLE,
}

const HTTP_BASE_URL := "https://api.wompout.com"
const WEBSOCKET_URL := "wss://api.wompout.com/ws"

const HTTP_TIMEOUT_SECONDS := 10.0
const WEBSOCKET_TIMEOUT_SECONDS := 8.0

const ACCESS_TOKEN_EXPIRATION_SECONDS := 900
const REFRESH_MARGIN_SECONDS := 30

var access_token := ""
var refresh_token := ""
var session_refresh_at := 0.0
var session_refresh_pending := false

var socket := WebSocketPeer.new()
var websocket_authenticated := false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	var current_socket := socket
	current_socket.poll()

	while socket == current_socket and current_socket.get_available_packet_count() > 0:
		var text := current_socket.get_packet().get_string_from_utf8()
		_handle_websocket_message(_parse_websocket_message(text))

	if socket != current_socket:
		return

	if current_socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		disconnect_websocket()
		websocket_disconnected.emit()
		return

	if websocket_authenticated and not session_refresh_pending:
		if Time.get_ticks_msec() / 1000.0 >= session_refresh_at:
			_refresh_session()


func authenticate() -> AuthResult:
	refresh_token = _load_refresh_token()
	return await _refresh_session()


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	session_refresh_at = 0.0
	_save_refresh_token("")


func auth_create_guest(display_name: String) -> Dictionary:
	var response: Dictionary = await _request(
		"/auth/guest",
		{"displayName": display_name.strip_edges()}
	)
	return _handle_token_response(response)


func auth_start_signup(display_name: String, email: String) -> Dictionary:
	return await _request(
		"/auth/signup/start",
		{
			"displayName": display_name.strip_edges(),
			"email": email.strip_edges().to_lower(),
		}
	)


func auth_verify_signup(email: String, code: String) -> Dictionary:
	var response: Dictionary = await _request(
		"/auth/signup/verify",
		{
			"email": email.strip_edges().to_lower(),
			"code": code.strip_edges(),
		}
	)
	return _handle_token_response(response)


func auth_start_login(email: String) -> Dictionary:
	return await _request(
		"/auth/login/start",
		{"email": email.strip_edges().to_lower()}
	)


func auth_verify_login(email: String, code: String) -> Dictionary:
	var response: Dictionary = await _request(
		"/auth/login/verify",
		{
			"email": email.strip_edges().to_lower(),
			"code": code.strip_edges(),
		}
	)
	return _handle_token_response(response)


func auth_start_link(email: String) -> Dictionary:
	return await _authenticated_request(
		"/auth/link/start",
		{"email": email.strip_edges().to_lower()}
	)


func auth_verify_link(email: String, code: String) -> Dictionary:
	return await _authenticated_request(
		"/auth/link/verify",
		{
			"email": email.strip_edges().to_lower(),
			"code": code.strip_edges(),
		}
	)


func sessions_logout() -> Dictionary:
	return await _authenticated_request(
		"/sessions/logout",
	)


func lobbies_invite_player(player_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invite",
		{"invitedPlayerId": player_id}
	)


func lobbies_accept_invite(invite_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invites/%s/accept" % invite_id.uri_encode()
	)


func lobbies_decline_invite(invite_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invites/%s/decline" % invite_id.uri_encode()
	)


func lobbies_leave_lobby() -> Dictionary:
	return await _authenticated_request(
		"/lobbies/leave"
	)


func lobbies_update_mode(mode_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/mode",
		{"mode": mode_id}
	)


func lobbies_update_ready(ready: bool) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/ready",
		{"ready": ready}
	)


func lobbies_update_loadout(loadout: Dictionary) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/loadout",
		loadout
	)


func friends_create_invite() -> Dictionary:
	return await _authenticated_request(
		"/friends/invite"
	)


func friends_redeem_invite(token: String) -> Dictionary:
	return await _authenticated_request(
		"/friends/invite/%s/redeem" % token.uri_encode()
	)


func matches_acknowledge_match(game_id: String) -> Dictionary:
	return await _authenticated_request(
		"/matches/%s/acknowledge" % game_id.uri_encode()
	)


func players_open_chest() -> Dictionary:
	return await _authenticated_request(
		"/players/open"
	)


func shop_buy_offer(offer_id: String) -> Dictionary:
	return await _authenticated_request(
		"/shop/buy",
		{"offerId": offer_id}
	)


func connect_websocket() -> bool:
	disconnect_websocket()

	var current_socket := socket
	var token := await _get_valid_access_token()

	if socket != current_socket:
		return false
	if token.is_empty():
		return false

	var err := current_socket.connect_to_url(WEBSOCKET_URL)
	if err != OK:
		disconnect_websocket()
		return false

	var deadline := (
		Time.get_ticks_msec()
		+ int(WEBSOCKET_TIMEOUT_SECONDS * 1000)
	)

	while (
		socket == current_socket
		and current_socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING
		and Time.get_ticks_msec() < deadline
	):
		current_socket.poll()
		await get_tree().process_frame

	if socket != current_socket:
		return false

	if current_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		disconnect_websocket()
		return false

	if await _authenticate_websocket():
		return true

	if socket == current_socket:
		disconnect_websocket()

	return false


func disconnect_websocket() -> void:
	set_process(false)
	websocket_authenticated = false
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()
	socket = WebSocketPeer.new()


func subscribe_resources(resources: Array[String]) -> bool:
	if not websocket_authenticated:
		push_error("Couldn't subscribe: WebSocket isn't authenticated or open.")
		return false
	var err := socket.send_text(JSON.stringify({
		"event": "subscribe",
		"data": {
			"resources": resources,
		},
	}))
	if err != OK:
		push_error("Couldn't subscribe to %s: %s" % [str(resources), error_string(err)])
		return false
	return true


func unsubscribe_resources(resources: Array[String]) -> bool:
	if not websocket_authenticated:
		push_error("Couldn't unsubscribe: WebSocket isn't authenticated or open.")
		return false
	var err := socket.send_text(JSON.stringify({
		"event": "unsubscribe",
		"data": {
			"resources": resources,
		},
	}))
	if err != OK:
		push_error("Couldn't unsubscribe from %s: %s" % [str(resources), error_string(err)])
		return false
	return true


func _get_valid_access_token() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if not session_refresh_pending and not access_token.is_empty() and now < session_refresh_at:
		return access_token
	var result := await _refresh_session()
	return access_token if result == AuthResult.SUCCEEDED else ""


func _refresh_session() -> AuthResult:
	if session_refresh_pending:
		return await session_refresh_finished

	if refresh_token.is_empty():
		return AuthResult.AUTH_REQUIRED

	session_refresh_pending = true

	var current_socket := socket
	var had_connection := websocket_authenticated
	var previous_refresh_token := refresh_token
	var result := AuthResult.SERVER_UNAVAILABLE

	var response := await _request(
		"/sessions/refresh",
		{"refreshToken": previous_refresh_token}
	)

	if refresh_token == previous_refresh_token:
		if response.get("status", 0) == 401:
			clear_session()
			result = AuthResult.AUTH_REQUIRED
		else:
			response = _handle_token_response(response)

			if response.get("ok", false):
				result = AuthResult.SUCCEEDED

				if had_connection:
					if socket != current_socket:
						result = AuthResult.SERVER_UNAVAILABLE
					elif not await _authenticate_websocket():
						result = AuthResult.SERVER_UNAVAILABLE

	if result != AuthResult.SUCCEEDED:
		if had_connection and socket == current_socket:
			disconnect_websocket()
			websocket_disconnected.emit()

	session_refresh_pending = false
	session_refresh_finished.emit(result)
	return result


func _handle_token_response(response: Dictionary) -> Dictionary:
	if not response["ok"]:
		return response

	var data: Variant = response["data"]
	if not data is Dictionary:
		push_error("Token response is not a dictionary")
		response["ok"] = false
		return response
	
	var new_access_token: Variant = data.get("access_token")
	var new_refresh_token: Variant = data.get("refresh_token")
	
	if not new_access_token is String or not new_refresh_token is String:
		push_error("Token response contains invalid token types")
		response["ok"] = false
		return response

	if new_access_token.is_empty() or new_refresh_token.is_empty():
		push_error("Token response contains empty tokens")
		response["ok"] = false
		return response
	
	access_token = new_access_token
	refresh_token = new_refresh_token
	session_refresh_at = (
		Time.get_ticks_msec() / 1000.0
		+ ACCESS_TOKEN_EXPIRATION_SECONDS
		- REFRESH_MARGIN_SECONDS
	)
	_save_refresh_token(refresh_token)
	return response


func _authenticated_request(path: String, body: Variant = null, method := HTTPClient.METHOD_POST) -> Dictionary:
	var token := await _get_valid_access_token()
	if token.is_empty():
		return {"ok": false, "status": 0, "data": null}
	var headers: Array[String] = ["Authorization: Bearer " + token]
	return await _request(path, body, headers, method)


func _request(path: String, body: Variant = null, headers: Array[String] = [], method := HTTPClient.METHOD_POST) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(http)
	
	var final_headers := ["Content-Type: application/json"]
	final_headers.append_array(headers)

	var request_body := JSON.stringify(body) if body != null else ""
	var err := http.request(HTTP_BASE_URL + path, final_headers, method, request_body)
	
	if err != OK:
		http.queue_free()
		push_error("Couldn't start request to %s: %s" % [path, err])
		return {"ok": false, "status": 0, "data": null}

	var response: Array = await http.request_completed
	http.queue_free()
	
	var transport_result: int = response[0]
	var status: int = response[1]
	
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		push_error("Transport failed for %s: %s" % [path, transport_result])
		return {"ok": false, "status": status, "data": null}

	var bytes: PackedByteArray = response[3]
	var text := bytes.get_string_from_utf8().strip_edges()
	var data: Variant = null
	
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) != OK:
			push_error("Invalid JSON response from " + path)
			return {"ok": false, "status": status, "data": null}
		data = json.data

	return {
		"ok": status >= 200 and status < 300,
		"status": status,
		"data": data,
	}


func _authenticate_websocket() -> bool:
	var current_socket := socket
	var token := access_token

	set_process(false)

	if token.is_empty():
		return false
	if current_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false

	var err := current_socket.send_text(JSON.stringify({
		"event": "authenticate",
		"data": {"accessToken": token},
	}))

	if err != OK:
		return false

	var deadline := (
		Time.get_ticks_msec()
		+ int(WEBSOCKET_TIMEOUT_SECONDS * 1000)
	)

	while (
		socket == current_socket
		and access_token == token
		and Time.get_ticks_msec() < deadline
	):
		current_socket.poll()

		if current_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return false

		while current_socket.get_available_packet_count() > 0:
			var text := current_socket.get_packet().get_string_from_utf8()
			var message := _parse_websocket_message(text)

			match str(message.get("event", "")):
				"authenticated":
					websocket_authenticated = true
					set_process(true)
					return true
				"error":
					_handle_websocket_message(message)
					return false
				_:
					_handle_websocket_message(message)

			if socket != current_socket or access_token != token:
				return false

		await get_tree().process_frame

	return false


func _handle_websocket_message(message: Dictionary) -> void:
	var data: Variant = message.get("data")
	if not data is Dictionary:
		return
	
	match str(message.get("event", "")):
		"subscribed":
			var snapshots: Variant = data.get("snapshots")
			if not snapshots is Dictionary:
				return
			subscribed.emit(snapshots)
		"unsubscribed":
			var resources: Variant = data.get("resources")
			if not resources is Array:
				return
			unsubscribed.emit(resources)
		"state":
			if not data.has("snapshot"):
				return
			_handle_resource_snapshot(str(data.get("resource", "")), data["snapshot"])
		"error":
			error.emit(str(data.get("message", "Request failed")))


func _handle_resource_snapshot(resource: String, snapshot: Variant) -> void:
	match resource:
		"player":
			if snapshot is Dictionary:
				player_updated.emit(snapshot)
		"lobby":
			if snapshot is Dictionary:
				lobby_updated.emit(snapshot)
		"lobbyInvites":
			if snapshot is Array:
				lobby_invites_updated.emit(snapshot)
		"match":
			if snapshot == null or snapshot is Dictionary:
				match_updated.emit(snapshot)
		"friends":
			if snapshot is Dictionary:
				friends_updated.emit(snapshot)
		"rankings":
			if snapshot is Dictionary:
				rankings_updated.emit(snapshot)
		"shop":
			if snapshot is Dictionary:
				shop_updated.emit(snapshot)


func _parse_websocket_message(text: String) -> Dictionary:
	var message: Variant = JSON.parse_string(text)
	if message is Dictionary:
		return message
	return {}


func _save_refresh_token(token: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", token)
	var err := cfg.save(_get_session_file_path())
	if err != OK:
		push_error("Couldn't save session: %s" % error_string(err))


func _load_refresh_token() -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load(_get_session_file_path())
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_error("Couldn't load session: %s" % error_string(err))
		return ""
	return str(cfg.get_value("auth", "refresh_token", ""))


func _get_session_file_path() -> String:
	for suffix in ["1", "2", "3", "4"]:
		if OS.has_feature(suffix):
			return "user://session%s.cfg" % suffix
	return "user://session.cfg"
