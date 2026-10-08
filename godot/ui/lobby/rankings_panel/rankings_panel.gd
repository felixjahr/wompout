extends LobbyPanel

signal closed

const PlayerEntry := preload("res://ui/lobby//player_entry/player_entry.tscn")

@onready var player_entry_container := %PlayerEntryContainer


func render_rankings(rankings: Dictionary) -> void:
	for child in player_entry_container.get_children():
		child.queue_free()
	for player in rankings["players"]:
		var player_entry := PlayerEntry.instantiate()
		player_entry_container.add_child(player_entry)
		player_entry.render_player_entry(player, false, false)


func _on_close_button_pressed() -> void:
	closed.emit()
