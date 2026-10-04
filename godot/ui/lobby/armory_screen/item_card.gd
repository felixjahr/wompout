extends ShrinkButton

@onready var item_texture_rect := %ItemTextureRect


func render_item_card(category_id: String, item_id: String):
	item_texture_rect.texture = Data.CATEGORIES[category_id][item_id].card_texture
