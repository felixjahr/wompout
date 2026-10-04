extends LobbyPanel

signal add_friends_button_pressed
signal player_invited(playerId: String)

const PlayerEntry := preload("res://ui/lobby/player_entry.tscn")

@onready var online_container := %OnlineContainer
@onready var offline_container := %OfflineContainer
@onready var online_label := %OnlineLabel
@onready var offline_label := %OfflineLabel

@onready var add_friends_button := %AddFriendsButton


func render_friends_panel(players: Array) -> void:
	for container in [online_container, offline_container]:
		for child in container.get_children():
			child.queue_free()
	
	var sorted_players := players.duplicate()
	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["trophies"]) > int(b["trophies"])
	)
	
	var online_count := 0
	var offline_count := 0
	for player in sorted_players:
		var player_entry := PlayerEntry.instantiate()
		var container: Control
		if player["status"] == "offline":
			container = offline_container
			offline_count += 1
		else:
			container = online_container
			online_count += 1
		player_entry.invite_pressed.connect(player_invited.emit)
		container.add_child(player_entry)
		player_entry.render_player_entry(player)
	
	online_label.text = "ONLINE: " + str(online_count)
	offline_label.text = "OFFLINE: " + str(offline_count)


func _on_close_button_pressed() -> void:
	animate_panel(false)


func _on_add_friends_button_pressed() -> void:
	add_friends_button_pressed.emit()
