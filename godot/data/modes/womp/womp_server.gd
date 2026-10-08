extends ModeServer

var received_players: Dictionary = {}


func _on_player_received(player_id: String) -> void:
	received_players[player_id] = true


func _process(delta: float) -> void:
	if state != ModeState.PREPARING:
		return
	
	for player in players:
		var player_id := str(player["id"])

		if not remaining_ids.has(player_id):
			continue

		if not received_players.has(player_id):
			return
	
	_change_state(ModeState.FIGHT)
