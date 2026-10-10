extends Control

signal item_equipped

@onready var equip_popup := %EquipPopup
@onready var item_card := %ItemCard


func render_item_entry(category_id: String, item_id: String, loadout: Dictionary):
	item_card.render_item_card(category_id, item_id)
	equip_popup.hide()
	var item_card_panel_stylebox: StyleBoxFlat = item_card.get_child(0).get_theme_stylebox("panel").duplicate()
	if loadout[category_id + "Id"] == item_id:
		item_card_panel_stylebox.bg_color = Color("3d70ff")
	else:
		item_card_panel_stylebox.bg_color = Color("151a21")
	item_card.get_child(0).add_theme_stylebox_override("panel", item_card_panel_stylebox)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if equip_popup.visible:
		var local_mouse = equip_popup.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, equip_popup.size).has_point(local_mouse):
			equip_popup.hide()


func _on_equip_button_pressed() -> void:
	equip_popup.hide()
	item_equipped.emit()


func _on_item_card_pressed() -> void:
	equip_popup.visible = !equip_popup.visible


func _on_equip_popup_visibility_changed() -> void:
	z_index = 1 if equip_popup.visible else 0
