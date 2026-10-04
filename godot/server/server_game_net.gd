extends Node

<<<<<<< HEAD
signal input_batch_received(player_id: String, input_batch: ParticipantInputBatch)
=======
signal input_batch_received(player_id: String, input_batch: PlayerInputBatch)
>>>>>>> origin/main
signal game_request_received(player_id: String, game_request: GameRequest)
signal player_authenticated(player_id: String)
signal player_disconnected(player_id: String)

const AUTH_TIMEOUT := 5.0
<<<<<<< HEAD
const MAX_RESEND_EVENTS := 3
=======
>>>>>>> origin/main

var allowed_players: Dictionary = {}
var player_id_by_pid: Dictionary[int, String] = {}
var pid_by_player_id: Dictionary[String, int] = {}
var unauthenticated_connected_at: Dictionary[int, float] = {}

<<<<<<< HEAD
var pending_events: Array[EventSnapshot] = []
var event_send_count: Dictionary[String, int] = {}
var event_counter := 0

=======
>>>>>>> origin/main

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
<<<<<<< HEAD
	var now := Time.get_ticks_msec() / 1000.0
=======
	var now := Time.get_unix_time_from_system()
>>>>>>> origin/main
	for pid in unauthenticated_connected_at.keys():
		if now - unauthenticated_connected_at[pid] >= AUTH_TIMEOUT:
			unauthenticated_connected_at.erase(pid)
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(pid)


func create_server(port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		push_error("Failed to create game server: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	return true


func has_connected_peer(pid: int) -> bool:
	if not multiplayer.multiplayer_peer:
		return false
	return multiplayer.get_peers().has(pid)


<<<<<<< HEAD
func send_snapshot(snapshot: Snapshot, participant_teams: Dictionary) -> void:
	if not multiplayer.multiplayer_peer:
		pending_events.clear()
		event_send_count.clear()
		return
	if multiplayer.get_peers().is_empty():
		pending_events.clear()
		event_send_count.clear()
		return
	snapshot.events = pending_events.duplicate()
	for player_id in pid_by_player_id:
		var pid: int = pid_by_player_id[player_id]
		snapshot.local_team_id = int(participant_teams[player_id])
		rpc_id(pid, "receive_snapshot", snapshot.to_packet())
	for event in snapshot.events:
		event_send_count[event.event_id] += 1
		if event_send_count[event.event_id] >= MAX_RESEND_EVENTS:
			pending_events.erase(event)
			event_send_count.erase(event.event_id)
=======
func send_snapshot(snapshot: Snapshot) -> void:
	if not multiplayer.multiplayer_peer:
		return
	if multiplayer.get_peers().is_empty():
		return
	rpc("receive_snapshot", snapshot.to_packet())
>>>>>>> origin/main


@rpc("authority", "unreliable")
func receive_snapshot(snapshot: PackedByteArray) -> void:
	pass


<<<<<<< HEAD
func send_init(player_id: String, mode_id: String, map_id: String) -> void:
=======
func send_init(player_id: String, game_id: String, map_id: String) -> void:
>>>>>>> origin/main
	if not pid_by_player_id.has(player_id):
		return
	var pid: int = pid_by_player_id[player_id]
	if not has_connected_peer(pid):
		return
<<<<<<< HEAD
	rpc_id(pid, "receive_init", mode_id, map_id)


@rpc("authority", "reliable")
func receive_init(mode_id: String, map_id: String) -> void:
=======
	rpc_id(pid, "receive_init",game_id, map_id)


@rpc("authority", "reliable")
func receive_init(game_id: String, map_id: String) -> void:
>>>>>>> origin/main
	pass


func send_state_sync(player_id: String, state_sync: StateSync) -> void:
	if not pid_by_player_id.has(player_id):
		return
	var pid: int = pid_by_player_id[player_id]
	if not has_connected_peer(pid):
		return
	rpc_id(pid, "receive_state_sync", state_sync.to_dict())


@rpc("authority", "reliable")
func receive_state_sync(state_sync: Dictionary) -> void:
	pass


@rpc("any_peer", "unreliable")
func receive_input_batch(input_batch: PackedByteArray) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not player_id_by_pid.has(pid):
		return
	var player_id: String = player_id_by_pid[pid]
<<<<<<< HEAD
	emit_signal("input_batch_received", player_id, ParticipantInputBatch.from_packet(input_batch))
=======
	emit_signal("input_batch_received", player_id, PlayerInputBatch.from_packet(input_batch))
>>>>>>> origin/main

@rpc("any_peer", "reliable")
func receive_game_token(game_token: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	var token_hash := _hash_token(game_token)
	if not allowed_players.has(token_hash):
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.disconnect_peer(pid)
		return
	var player_id := ""
	player_id = str(allowed_players[token_hash])
	if player_id.is_empty():
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.disconnect_peer(pid)
		return
	if pid_by_player_id.has(player_id):
		var old_pid := pid_by_player_id[player_id]
		if old_pid != pid:
			player_id_by_pid.erase(old_pid)
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(old_pid)
	pid_by_player_id[player_id] = pid
	player_id_by_pid[pid] = player_id
	unauthenticated_connected_at.erase(pid)
	emit_signal("player_authenticated", player_id)


@rpc("any_peer", "reliable")
func receive_game_request(game_request: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not player_id_by_pid.has(pid):
		return
	var player_id: String = player_id_by_pid[pid]
	emit_signal("game_request_received", player_id, GameRequest.from_dict(game_request))


func _on_peer_disconnected(pid: int) -> void:
	unauthenticated_connected_at.erase(pid)
	if not player_id_by_pid.has(pid):
		return
	var player_id := player_id_by_pid[pid]
	player_id_by_pid.erase(pid)
	if pid_by_player_id.get(player_id) == pid:
		pid_by_player_id.erase(player_id)
	emit_signal("player_disconnected", player_id)


func _on_peer_connected(pid: int) -> void:
<<<<<<< HEAD
	unauthenticated_connected_at[pid] = Time.get_ticks_msec() / 1000.0
=======
	unauthenticated_connected_at[pid] = Time.get_unix_time_from_system()
>>>>>>> origin/main


func _hash_token(token: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(token.to_utf8_buffer())
	return ctx.finish().hex_encode()
<<<<<<< HEAD


func queue_event(event: EventSnapshot) -> void:
	event.event_id = str(event_counter)
	event_counter += 1
	pending_events.append(event)
	event_send_count[event.event_id] = 0
=======
>>>>>>> origin/main
