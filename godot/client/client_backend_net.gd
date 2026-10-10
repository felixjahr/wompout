extends Node

signal subscribed(snapshots: Dictionary)
signal unsubscribed(resources: Array)
signal error(message: String)

signal player_updated(player: Dictionary)
signal lobby_updated(lobby: Dictionary)
signal lobby_invites_updated(invites: Array)
signal match_updated(snapshot: Variant)
signal friends_updated(friends: Dictionary)
signal rankings_updated(rankings: Array)
signal shop_updated(shop: Dictionary)

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
var access_token_expires_at := 0.0

var socket := WebSocketPeer.new()
var websocket_authenticated := false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	socket.poll()
	
	while socket.get_available_packet_count() > 0:
		_handle_websocket_message(socket.get_packet().get_string_from_utf8())
	
	if websocket_authenticated and socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		websocket_authenticated = false
		set_process(false)
		emit_signal("websocket_disconnected")


func authenticate() -> AuthResult:
	refresh_token = _load_refresh_token()
	if refresh_token.is_empty():
		return AuthResult.AUTH_REQUIRED
	var result := await _refresh_session()
	if result == AuthResult.AUTH_REQUIRED:
		clear_session()
	return result


func auth_create_guest(displayName: String) -> Dictionary:
	var response: Dictionary = await _request(
		"/auth/guest",
		{"displayName": displayName.strip_edges()}
	)
	return _handle_token_response(response)


func auth_start_signup(displayName: String, email: String) -> Dictionary:
	return await _request(
		"/auth/signup/start",
		{
			"displayName": displayName.strip_edges(),
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
	access_token_expires_at = (
		Time.get_ticks_msec() / 1000.0
		+ ACCESS_TOKEN_EXPIRATION_SECONDS
		- REFRESH_MARGIN_SECONDS
	)
	_save_refresh_token(refresh_token)
	return response


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


func connect_websocket() -> bool:
	disconnect_websocket()
	socket = WebSocketPeer.new()

	var err := socket.connect_to_url(WEBSOCKET_URL)
	if err != OK:
		push_error("Couldn't start WebSocket connection: " + error_string(err))
		disconnect_websocket()
		return false

	var timeout := get_tree().create_timer(WEBSOCKET_TIMEOUT_SECONDS)

	while socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING and timeout.time_left > 0.0:
		socket.poll()
		await get_tree().process_frame

	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if timeout.time_left <= 0.0:
			push_error("WebSocket connection timed out.")
		else:
			push_error("WebSocket connection failed.")
		disconnect_websocket()
		return false
	
	var token := await _get_valid_access_token()
	if token.is_empty():
		push_error("Couldn't authenticate WebSocket: no valid access token.")
		disconnect_websocket()
		return false

	err = socket.send_text(JSON.stringify({
		"event": "authenticate",
		"data": {
			"accessToken": token,
		},
	}))

	if err != OK:
		push_error("Couldn't send WebSocket authentication: " + error_string(err))
		disconnect_websocket()
		return false

	timeout = get_tree().create_timer(WEBSOCKET_TIMEOUT_SECONDS)

	while timeout.time_left > 0.0:
		socket.poll()

		if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			push_error("WebSocket disconnected during authentication.")
			disconnect_websocket()
			return false

		while socket.get_available_packet_count() > 0:
			var text := socket.get_packet().get_string_from_utf8()
			var message := _parse_websocket_message(text)
			var data: Variant = message.get("data", {})

			if not data is Dictionary:
				continue

			match str(message.get("event", "")):
				"authenticated":
					websocket_authenticated = true
					set_process(true)
					return true
				"error":
					push_error("WebSocket authentication failed: " + str(data.get("message", "Unknown error")))
					disconnect_websocket()
					return false

		await get_tree().process_frame

	push_error("WebSocket authentication timed out.")
	disconnect_websocket()
	return false


func disconnect_websocket() -> void:
	set_process(false)
	websocket_authenticated = false
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()
	socket = WebSocketPeer.new()


func _handle_websocket_message(text: String) -> void:
	var message := _parse_websocket_message(text)
	if message.is_empty():
		return
	
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
			if snapshot is Array:
				rankings_updated.emit(snapshot)
		"shop":
			if snapshot is Dictionary:
				shop_updated.emit(snapshot)


func _parse_websocket_message(text: String) -> Dictionary:
	var message: Variant = JSON.parse_string(text)

	if message is Dictionary:
		return message

	return {}


func _refresh_session() -> AuthResult:
	var response: Dictionary = await _request(
		"/sessions/refresh",
		{"refreshToken": refresh_token}
	)
	
	if response.get("status", 0) == 401:
		return AuthResult.AUTH_REQUIRED
	
	if not response.get("ok", false):
		return AuthResult.SERVER_UNAVAILABLE
	
	var data = response.get("data")
	if not data is Dictionary:
		return AuthResult.SERVER_UNAVAILABLE

	var new_access_token := str(data.get("access_token", ""))
	var new_refresh_token := str(data.get("refresh_token", ""))

	if new_access_token.is_empty() or new_refresh_token.is_empty():
		return AuthResult.SERVER_UNAVAILABLE

	access_token = new_access_token
	refresh_token = new_refresh_token
	access_token_expires_at = (
		Time.get_ticks_msec() / 1000.0
		+ ACCESS_TOKEN_EXPIRATION_SECONDS 
		- REFRESH_MARGIN_SECONDS
	)
	_save_refresh_token(refresh_token)
	return AuthResult.SUCCEEDED


func clear_session() -> void:
	access_token = ""
	refresh_token = ""
	access_token_expires_at = 0.0
	_save_refresh_token("")


func _save_refresh_token(token: String) -> void:
	# Debug only
	var suffix := ""
	if OS.has_feature("1"):
		suffix = "1"
	elif OS.has_feature("2"):
		suffix = "2"
	elif OS.has_feature("3"):
		suffix = "3"
	elif OS.has_feature("4"):
		suffix = "4"
	
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "refresh_token", token)
	cfg.save("user://session" + suffix + ".cfg")


func _load_refresh_token() -> String:
	# Debug only
	var suffix := ""
	if OS.has_feature("1"):
		suffix = "1"
	elif OS.has_feature("2"):
		suffix = "2"
	elif OS.has_feature("3"):
		suffix = "3"
	elif OS.has_feature("4"):
		suffix = "4"
	
	var cfg := ConfigFile.new()
	var err := cfg.load("user://session" + suffix + ".cfg")
	if err != OK:
		return ""
	return str(cfg.get_value("auth", "refresh_token", ""))


func _get_valid_access_token() -> String:
	if not access_token.is_empty() and Time.get_ticks_msec() / 1000.0 < access_token_expires_at:
		return access_token
	if await _refresh_session() == AuthResult.SUCCEEDED:
		return access_token
	return ""
