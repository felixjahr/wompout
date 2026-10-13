extends AnimatedButton

signal buy_offer_requested(offer_id: String)

const BUY_BUTTON_PANEL_TEXTURE := {
	"can_afford": preload("res://ui/shared/animated_button/blue_button.png"),
	"cannot_afford": preload("res://ui/shared/animated_button/grey_button.png")
}

const CURRENCY_TEXTURES := {
	"coins": preload("res://ui/lobby/coin.png"),
	"gems": preload("res://ui/lobby/gem.png"),
}

var offer_id: String
var owned: bool
var can_afford: bool

@onready var panel := %Panel
@onready var buy_button_panel := %BuyButtonPanel
@onready var item_card := %ItemCard
@onready var currency_texture_rect := %CurrencyTextureRect
@onready var currency_label := %CurrencyLabel
@onready var name_label := %NameLabel


func render_shop_entry(category_id: String, item_id: String, currency_type: String, currency_amount: int, offer_id: String, can_afford := true, owned := false) -> void:
	self.offer_id = offer_id
	self.owned = owned
	self.can_afford = can_afford
	item_card.render_item_card(category_id, item_id)
	name_label.text = item_id.to_upper().replace("_", " ")
	var buy_button_panel_stylebox: StyleBoxTexture = buy_button_panel.get_theme_stylebox("panel").duplicate()
	var panel_stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	if can_afford and not owned:
		buy_button_panel_stylebox.texture = BUY_BUTTON_PANEL_TEXTURE["can_afford"]
		panel_stylebox.bg_color = Color("353f4f")
	else:
		buy_button_panel_stylebox.texture = BUY_BUTTON_PANEL_TEXTURE["cannot_afford"]
		panel_stylebox.bg_color = Color("6F6B6C")
	buy_button_panel.add_theme_stylebox_override("panel", buy_button_panel_stylebox)
	panel.add_theme_stylebox_override("panel", panel_stylebox)
	if not owned:
		currency_texture_rect.show()
		currency_texture_rect.texture = CURRENCY_TEXTURES[currency_type]
		currency_label.text = str(int(currency_amount))
	else:
		currency_texture_rect.hide()
		currency_label.text = "OWNED"


func _on_buy_button_pressed() -> void:
	if owned:
		get_node("/root/Controller").show_error("You already own this item.")
	elif not can_afford:
		get_node("/root/Controller").show_error("You don’t have enough currency to buy this item.")
	else:
		buy_offer_requested.emit(offer_id)
