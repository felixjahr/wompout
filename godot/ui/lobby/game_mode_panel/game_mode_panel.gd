extends LobbyPanel

signal game_mode_selected(mode_id: String)

const GAME_MODE_ENTRY := preload("res://ui/lobby/game_mode_panel/game_mode_entry.tscn")

@onready var ranked_container := %RankedContainer
@onready var unranked_container := %UnrankedContainer


func render_game_mode_panel() -> void:
	for child in ranked_container.get_children():
		child.queue_free()
	for child in unranked_container.get_children():
		child.queue_free()
	for mode_id in Data.MODE_IDS:
		var new_game_mode_entry := GAME_MODE_ENTRY.instantiate()
		if Data.MODES[mode_id].ranked:
			ranked_container.add_child(new_game_mode_entry)
		else:
			unranked_container.add_child(new_game_mode_entry)
		new_game_mode_entry.render_game_mode_entry(mode_id)
		new_game_mode_entry.pressed.connect(_on_game_mode_entry_pressed.bind(mode_id))


func _on_close_button_pressed() -> void:
	animate_panel(false)


func _on_game_mode_entry_pressed(mode_id: String) -> void:
	animate_panel(false)
	game_mode_selected.emit(mode_id)
