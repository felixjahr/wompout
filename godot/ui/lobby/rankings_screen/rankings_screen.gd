extends AnimatedPanel

const PlayerEntry := preload("res://ui/shared/player_entry/player_entry.tscn")

@onready var lobby := get_parent()
@onready var player_entry_container := %PlayerEntryContainer


func open() -> void:
	animate_panel(true)
	lobby.resource_opened.emit("rankings")


func update_rankings(rankings: Dictionary) -> void:
	for child in player_entry_container.get_children():
		child.queue_free()
	for player in rankings["players"]:
		var player_entry := PlayerEntry.instantiate()
		player_entry_container.add_child(player_entry)
		player_entry.render_player_entry(player, false, false, player["id"] == lobby.local_player_id)


func _close() -> void:
	animate_panel(false)
	lobby.resource_closed.emit("rankings")
