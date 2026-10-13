extends AnimatedPanel

const GAME_MODE_ENTRY := preload("res://ui/lobby/game_mode_screen/game_mode_entry.tscn")

@onready var scroll_container := %ScrollContainer
@onready var lobby := get_parent()
@onready var ranked_container := %RankedContainer
@onready var unranked_container := %UnrankedContainer


func _ready() -> void:
	for mode_id in Data.MODE_IDS:
		var new_game_mode_entry := GAME_MODE_ENTRY.instantiate()
		if Data.MODES[mode_id].ranked:
			ranked_container.add_child(new_game_mode_entry)
		else:
			unranked_container.add_child(new_game_mode_entry)
		new_game_mode_entry.render_game_mode_entry(mode_id)
		new_game_mode_entry.pressed.connect(_on_game_mode_entry_pressed.bind(mode_id))


func open() -> void:
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	animate_panel(true)


func _close() -> void:
	animate_panel(false)


func _on_game_mode_entry_pressed(mode_id: String) -> void:
	lobby.update_mode_requested.emit(mode_id)
	_close()
