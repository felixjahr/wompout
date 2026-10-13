extends AnimatedPanel

const SHOP_ENTRY := preload("res://ui/lobby/shop_screen/shop_entry.tscn")

var shop: Dictionary
var player: Dictionary

@onready var scroll_container := %ScrollContainer
@onready var lobby_screen := get_parent()
@onready var category_containers := {
	"melee": %MeleeContainer,
	"ranged": %RangedContainer,
	"armour": %ArmourContainer,
	"ability": %AbilityContainer,
	"style": %StyleContainer,
}


func open() -> void:
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	lobby_screen.resource_opened.emit("shop")
	animate_panel(true)


func update_shop(shop: Dictionary) -> void:
	self.shop = shop
	_update(shop, player)


func update_player(player: Dictionary) -> void:
	self.player = player
	if shop:
		_update(shop, player)


func _update(shop: Dictionary, player: Dictionary) -> void:
	for container in category_containers.values():
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for offer in shop["offers"]:
		var item_id: String = offer["itemId"]
		var price: Dictionary = offer["price"]
		for category_id in category_containers:
			if not Data.CATEGORIES[category_id].has(item_id):
				continue
			var new_shop_entry := SHOP_ENTRY.instantiate()
			new_shop_entry.buy_offer_requested.connect(lobby_screen.buy_offer_requested.emit)
			category_containers[category_id].add_child(new_shop_entry)
			var can_afford: bool = player[offer["price"]["currency"]] >= offer["price"]["amount"]
			var owned := false
			for item in player["items"]:
				if item["itemId"] == offer["itemId"]:
					owned = true
					break
			new_shop_entry.render_shop_entry(category_id, item_id, price["currency"], price["amount"], offer["offerId"], can_afford, owned)
			break


func _close() -> void:
	lobby_screen.resource_closed.emit("shop")
	shop = {}
	animate_panel(false)
