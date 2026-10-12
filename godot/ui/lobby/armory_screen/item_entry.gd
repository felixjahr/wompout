extends Control

signal selected

@onready var item_card := %ItemCard


func render_item_entry(category_id: String, item_id: String, loadout: Dictionary):
	item_card.render_item_card(category_id, item_id)
	var item_card_panel_stylebox: StyleBoxFlat = item_card.get_child(0).get_theme_stylebox("panel").duplicate()
	if loadout[category_id + "Id"] == item_id:
		item_card_panel_stylebox.bg_color = Color("3d70ff")
	else:
		item_card_panel_stylebox.bg_color = Color("151a21")
	item_card.get_child(0).add_theme_stylebox_override("panel", item_card_panel_stylebox)


func _on_item_card_pressed() -> void:
	selected.emit()
