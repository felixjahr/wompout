extends LobbyPanel

signal add_friends_button_pressed
signal player_invited(playerId: String)
signal closed

const PlayerEntry := preload("res://ui/lobby//player_entry/player_entry.tscn")

@onready var online_container := %OnlineContainer
@onready var offline_container := %OfflineContainer
@onready var online_label := %OnlineLabel
@onready var offline_label := %OfflineLabel

@onready var add_friends_button := %AddFriendsButton


func render_friends(friends: Dictionary) -> void:
	for container in [online_container, offline_container]:
		for child in container.get_children():
			child.queue_free()
	
	var sorted_players: Array = friends["players"].duplicate()
	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["trophies"]) > int(b["trophies"])
	)
	
	var online_count := 0
	var offline_count := 0
	for player in sorted_players:
		var player_entry := PlayerEntry.instantiate()
		var container: Control
		var offline: bool = true if player["status"] == "offline" else false
		if offline:
			container = offline_container
			offline_count += 1
		else:
			container = online_container
			online_count += 1
		player_entry.invite_pressed.connect(player_invited.emit)
		container.add_child(player_entry)
		player_entry.render_player_entry(player, not offline, not offline)
	
	online_label.text = "ONLINE: " + str(online_count)
	offline_label.text = "OFFLINE: " + str(offline_count)


func _on_add_friends_button_pressed() -> void:
	add_friends_button_pressed.emit()


func _on_close_button_pressed() -> void:
	closed.emit()
