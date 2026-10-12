extends AnimatedButton

@onready var item_texture_rect := %ItemTextureRect
@onready var panel := %Panel


func render_item_card(category_id: String, item_id: String, selected := false):
	item_texture_rect.texture = Data.CATEGORIES[category_id][item_id].card_texture
	var panel_stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	if selected:
		panel_stylebox.bg_color = Color("3d70ff")
	else:
		panel_stylebox.bg_color = Color("151a21")
	panel.add_theme_stylebox_override("panel", panel_stylebox)
