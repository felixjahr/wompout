extends Node

<<<<<<< HEAD
signal lobby_updated(lobby: Dictionary)
signal player_updated(player: Dictionary)
signal friends_updated(friends: Dictionary)
signal game_ready_received(ip: String, port: int, player_token: String)
signal game_over_received(data: Dictionary)
signal game_failed_received(reason: String)

signal websocket_disconnected

const HTTP_BASE_URL := "http://127.0.0.1:3000"
const WEBSOCKET_URL := "ws://127.0.0.1:3000/ws"

const WEBSOCKET_TIMEOUT_SECONDS := 8.0

var socket := WebSocketPeer.new()
var websocket_authenticated := false
=======
signal room_code_received(code: String)
signal room_start_received(port: int, ip: String, game_token: String, player_names: Dictionary)
signal room_failed_received

const HTTP_BASE := "http://46.224.63.244:8000"

const WS_URL := "ws://46.224.63.244:8000/ws"
const WS_CONNECT_TIMEOUT := 8.0
const WS_AUTH_TIMEOUT := 8.0
var socket := WebSocketPeer.new()
var socket_authed := false
>>>>>>> origin/main

@onready var auth_net := $"../AuthNet"


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	socket.poll()
<<<<<<< HEAD
	
	while socket.get_available_packet_count() > 0:
		_handle_websocket_message(socket.get_packet().get_string_from_utf8())
	
	if websocket_authenticated and socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		websocket_authenticated = false
		set_process(false)
		emit_signal("websocket_disconnected")


func invite_player(player_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invite",
		HTTPClient.METHOD_POST,
		{"invitedPlayerId": player_id}
	)


func accept_lobby_invite(invite_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invites/%s/accept" % invite_id,
		HTTPClient.METHOD_POST
	)


func decline_lobby_invite(invite_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/invites/%s/decline" % invite_id,
		HTTPClient.METHOD_POST
	)


func leave_lobby() -> Dictionary:
	return await _authenticated_request(
		"/lobbies/leave",
		HTTPClient.METHOD_POST
	)


func set_lobby_mode(mode_id: String) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/mode",
		HTTPClient.METHOD_POST,
		{"mode": mode_id}
	)


func set_lobby_ready(ready: bool) -> Dictionary:
	return await _authenticated_request(
		"/lobbies/ready",
		HTTPClient.METHOD_POST,
		{"ready": ready}
	)


func create_friend_invite() -> Dictionary:
	return await _authenticated_request(
		"/friends/invite",
		HTTPClient.METHOD_POST
	)


func redeem_friend_invite(token: String) -> Dictionary:
	return await _authenticated_request(
		"/friends/invite/%s/redeem" % token,
		HTTPClient.METHOD_POST
	)


func connect_websocket() -> bool:
	disconnect_websocket()

	socket = WebSocketPeer.new()

	if socket.connect_to_url(WEBSOCKET_URL) != OK:
		return false

	var timeout := get_tree().create_timer(WEBSOCKET_TIMEOUT_SECONDS)

	while (
		socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING
		and timeout.time_left > 0.0
	):
		socket.poll()
		await get_tree().process_frame

	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false

	var auth_data: Dictionary = (
		await auth_net.get_websocket_auth_data()
	)

	if auth_data.is_empty():
		return false

	if socket.send_text(JSON.stringify({
		"event": "auth",
		"data": auth_data,
	})) != OK:
		return false

	timeout = get_tree().create_timer(WEBSOCKET_TIMEOUT_SECONDS)

	while timeout.time_left > 0.0:
		socket.poll()

		while socket.get_available_packet_count() > 0:
			var message := _parse_websocket_message(
				socket.get_packet().get_string_from_utf8()
			)

			match str(message.get("event", "")):
				"authOk":
					websocket_authenticated = true
					set_process(true)
					return true

				"authFailed":
					return false

		await get_tree().process_frame

	return false


func disconnect_websocket() -> void:
	set_process(false)
	websocket_authenticated = false

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()

	socket = WebSocketPeer.new()


func _authenticated_request(
	path: String,
	method: HTTPClient.Method = HTTPClient.METHOD_GET,
	body: Variant = null
) -> Dictionary:
	var headers: Array[String] = await auth_net.get_auth_header()

	if headers.is_empty():
		return {"ok": false, "data": null}

	return await HttpUtils.request(
		self,
		HTTP_BASE_URL + path,
		method,
		body,
		headers
	)


func _handle_websocket_message(text: String) -> void:
	var message := _parse_websocket_message(text)

	if message.is_empty():
		return

	var event_name := str(message.get("event", ""))
	var data: Variant = message.get("data", {})

	match event_name:
		"lobbyUpdated":
			if data is Dictionary:
				lobby_updated.emit(data.get("lobby", {}))
		"playerUpdated":
			if data is Dictionary:
				player_updated.emit(data.get("player", {}))
		"friendsUpdated":
			if data is Dictionary:
				friends_updated.emit(data.get("friends", {}))
		"gameReady":
			if data is Dictionary:
				game_ready_received.emit(
					str(data.get("ip", "")),
					int(data.get("port", 0)),
					str(data.get("playerToken", ""))
				)
		"gameOver":
			if data is Dictionary:
				game_over_received.emit(data)
		"gameFailed":
			if data is Dictionary:
				game_failed_received.emit(
					data.get("reason", "")
				)


func _parse_websocket_message(text: String) -> Dictionary:
	var message: Variant = JSON.parse_string(text)

	if message is Dictionary:
		return message

	return {}
=======
	if socket_authed and socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		socket_authed = false
		set_process(false)
		emit_signal("room_failed_received")
		return
	while socket.get_available_packet_count() > 0:
		var msg = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not (msg is Dictionary):
			continue
		var event := str(msg.get("event", ""))
		var data: Dictionary = msg.get("data", {})
		match event:
			"receiveRoomStart":
				var ip := str(data.get("ip", ""))
				var port := int(data.get("port", 0))
				var game_token := str(data.get("gameToken", ""))
				var player_names = data.get("playerNames", {})
				if not (player_names is Dictionary):
					player_names = {}
				emit_signal("room_start_received", port, ip, game_token, player_names)
			"roomFailed":
				emit_signal("room_failed_received")


func create_room() -> void:
	if not (await _connect_ws()):
		emit_signal("room_failed_received")
		return
	var headers = await auth_net.get_auth_header()
	var response: Dictionary = await HttpUtils.request(
		self,
		HTTP_BASE + "/rooms/create",
		HTTPClient.METHOD_POST,
		null,
		headers,
	)
	if not response.get("ok", false) or response.get("data") == null:
		emit_signal("room_failed_received")
		return
	var data: Dictionary = response["data"]
	var code := str(data.get("code", ""))
	if code.is_empty():
		push_error("Backend returned an empty room code")
		emit_signal("room_failed_received")
		return
	emit_signal("room_code_received", code)


func join_room(code: String) -> void:
	if not (await _connect_ws()):
		emit_signal("room_failed_received")
		return
	var headers = await auth_net.get_auth_header()
	var response: Dictionary = await HttpUtils.request(
		self,
		HTTP_BASE + "/rooms/join/" + code,
		HTTPClient.METHOD_POST,
		null,
		headers,
	)
	if not response.get("ok", false):
		emit_signal("room_failed_received")


func leave_room(code: String) -> void:
	if code.is_empty():
		return
	var headers = await auth_net.get_auth_header()
	var response: Dictionary = await HttpUtils.request(
		self,
		HTTP_BASE + "/rooms/leave/" + code,
		HTTPClient.METHOD_POST,
		null,
		headers,
	)
	if not response.get("ok", false):
		push_error("Failed to leave room")


func _connect_ws() -> bool:
	if socket_authed and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return true
	socket_authed = false
	socket.close()
	socket = WebSocketPeer.new()
	socket.connect_to_url(WS_URL)
	var connect_timeout := get_tree().create_timer(WS_CONNECT_TIMEOUT)
	while socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING and connect_timeout.time_left > 0.0:
		socket.poll()
		await get_tree().process_frame
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("WebSocket failed to connect")
		return false
	if not await _send_auth():
		return false
	var retried_auth := false
	var auth_timeout := get_tree().create_timer(WS_AUTH_TIMEOUT)
	while auth_timeout.time_left > 0.0:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var msg = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if not (msg is Dictionary):
				continue
			var event := str(msg.get("event", ""))
			if event == "authOk":
				socket_authed = true
				set_process(true)
				return true
			if event == "authFailed" and not retried_auth:
				retried_auth = true
				if not await _send_auth():
					return false
		await get_tree().process_frame
	push_error("WebSocket auth timed out")
	return false


func _send_auth() -> bool:
	var err := socket.send_text(JSON.stringify({
		"event": "auth",
		"data": {
			"accessToken": await auth_net.get_valid_access_token()
		}
	}))
	if err != OK:
		push_error("WebSocket auth failed to send: %s" % err)
		return false
	return true
>>>>>>> origin/main
