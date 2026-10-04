extends Node

signal snapshot_received(snapshot: Snapshot)
<<<<<<< HEAD
signal init_received(mode_id: String, map_id: String)
signal state_sync_received(state_sync: StateSync)

signal connection_failed

const JOIN_TIMEOUT := 10.0

var connection_active := false
var game_token := ""
var join_timer := Timer.new()


func _ready() -> void:
	join_timer.one_shot = true
	add_child(join_timer)
	join_timer.timeout.connect(_on_connection_failed)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_connection_failed)


func create_client(port: int, ip: String, game_token: String) -> void:
	if connection_active:
		return

	connection_active = true
	self.game_token = game_token

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)

	if error != OK:
		_on_connection_failed()
		return

	multiplayer.multiplayer_peer = peer
	join_timer.start(JOIN_TIMEOUT)


func disconnect_from_server() -> void:
	connection_active = false
	game_token = ""
	join_timer.stop()
=======
signal init_received(game_id: String, map_id: String)
signal state_sync_received(state_sync: StateSync)


func create_client(port: int, ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create game client: %s" % err)
		return
	multiplayer.multiplayer_peer = peer


func disconnect_from_server() -> void:
>>>>>>> origin/main
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func is_connected_to_server() -> bool:
	if not multiplayer.multiplayer_peer:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


<<<<<<< HEAD
func send_input_batch(input_batch: ParticipantInputBatch) -> bool:
=======
func send_input_batch(input_batch: PlayerInputBatch) -> bool:
>>>>>>> origin/main
	if not is_connected_to_server():
		return false
	if input_batch.inputs.is_empty():
		return false
	rpc_id(1, "receive_input_batch", input_batch.to_packet())
	return true


func send_game_token(game_token: String) -> bool:
	if not is_connected_to_server():
		return false
	rpc_id(1, "receive_game_token", game_token)
	return true


func send_game_request(game_request: GameRequest) -> bool:
	if not is_connected_to_server():
		return false
	rpc_id(1, "receive_game_request", game_request.to_dict())
	return true


@rpc("authority", "unreliable")
func receive_snapshot(snapshot: PackedByteArray) -> void:
<<<<<<< HEAD
	if not connection_active:
		return
=======
>>>>>>> origin/main
	emit_signal("snapshot_received", Snapshot.from_packet(snapshot))


@rpc("authority", "reliable")
<<<<<<< HEAD
func receive_init(mode_id: String, map_id: String) -> void:
	if not connection_active:
		return
	emit_signal("init_received", mode_id, map_id)
=======
func receive_init(game_id: String, map_id: String) -> void:
	emit_signal("init_received", game_id, map_id)
>>>>>>> origin/main


@rpc("authority", "reliable")
func receive_state_sync(state_sync: Dictionary) -> void:
<<<<<<< HEAD
	if not connection_active:
		return
	join_timer.stop()
=======
>>>>>>> origin/main
	emit_signal("state_sync_received", StateSync.from_dict(state_sync))


@rpc("any_peer", "unreliable")
func receive_input_batch(input_batch: PackedByteArray) -> void:
	pass


@rpc("any_peer", "reliable")
func receive_game_token(game_token: String) -> void:
	pass


@rpc("any_peer", "reliable")
func receive_game_request(game_request: Dictionary) -> void:
	pass
<<<<<<< HEAD


func _on_connected_to_server() -> void:
	if not connection_active:
		return

	if not send_game_token(game_token):
		_on_connection_failed()
		return

	game_token = ""


func _on_connection_failed() -> void:
	if not connection_active:
		return

	disconnect_from_server()
	connection_failed.emit()
=======
>>>>>>> origin/main
