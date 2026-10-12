extends AnimatedPanel

const PlayerEntry := preload("res://ui/shared/player_entry/player_entry.tscn")

var friends: Dictionary
var lobby: Dictionary

@onready var lobby_screen := get_parent()
@onready var online_container := %OnlineContainer
@onready var offline_container := %OfflineContainer
@onready var online_label := %OnlineLabel
@onready var offline_label := %OfflineLabel
@onready var add_friends_button := %AddFriendsButton


func open() -> void:
	lobby_screen.resource_opened.emit("friends")
	animate_panel(true)


func update_friends(friends: Dictionary) -> void:
	self.friends = friends
	_update(friends, lobby)


func update_lobby(lobby: Dictionary) -> void:
	self.lobby = lobby
	if friends:
		_update(friends, lobby)


func _update(friends: Dictionary, lobby: Dictionary) -> void:
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
		player_entry.invite_pressed.connect(lobby_screen.invite_player_requested.emit)
		container.add_child(player_entry)
		var in_lobby := false
		for lobby_player in lobby["players"]:
			if lobby_player["id"] == player["id"]:
				in_lobby = true
				break
		var invited: bool = lobby["invitedPlayerIds"].has(player["id"])
		var invitable := not in_lobby and not invited and not offline
		player_entry.render_player_entry(player, not offline, invitable, in_lobby, invited)
	
	online_label.text = "ONLINE: " + str(online_count)
	offline_label.text = "OFFLINE: " + str(offline_count)


func _close() -> void:
	lobby_screen.resource_closed.emit("friends")
	friends = {}
	animate_panel(false)


func _on_add_friends_button_pressed() -> void:
	lobby_screen.create_invite_requested.emit()
