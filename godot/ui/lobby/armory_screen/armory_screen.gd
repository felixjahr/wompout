extends Control

const ITEM_CARD := preload("res://ui/shared/item_card/item_card.tscn")

var player: Dictionary
var current_category_id := "melee"
var selected_category_id := ""
var selected_item_id := ""

@onready var lobby := get_parent()
@onready var armory_panel := %ArmoryPanel
@onready var item_card_container := %ItemCardContainer
@onready var tab_button_container := %TabButtonContainer
@onready var platform := %Platform
@onready var equip_popup := %EquipPopup
@onready var selected_item_card := %SelectedItemCard
@onready var melee_button := %MeleeButton
@onready var ranged_button := %RangedButton
@onready var armour_button := %ArmourButton
@onready var ability_button := %AbilityButton
@onready var style_button := %StyleButton


func _ready() -> void:
	melee_button.pressed.connect(_on_category_button_pressed.bind("melee", melee_button))
	ranged_button.pressed.connect(_on_category_button_pressed.bind("ranged", ranged_button))
	armour_button.pressed.connect(_on_category_button_pressed.bind("armour", armour_button))
	ability_button.pressed.connect(_on_category_button_pressed.bind("ability", ability_button))
	style_button.pressed.connect(_on_category_button_pressed.bind("style", style_button))


func _input(event: InputEvent) -> void:
	if not equip_popup.is_visible_in_tree():
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var popup_rect := Rect2(Vector2.ZERO, equip_popup.size)
	if not popup_rect.has_point(equip_popup.get_local_mouse_position()):
		_close_equip_popup()


func open() -> void:
	lobby.platform_area.hide()
	lobby.upper_bar.hide()
	lobby.side_buttons.hide()
	lobby.lower_bar.hide()
	armory_panel.animate_panel(true)
	platform.show()
	_on_category_button_pressed("melee", melee_button)
	show()


func update_player(player: Dictionary) -> void:
	self.player = player
	platform.render_platform(player, false, true)
	_render_category(current_category_id)


func _close() -> void:
	lobby.platform_area.show()
	lobby.upper_bar.show()
	lobby.side_buttons.show()
	lobby.lower_bar.show()
	armory_panel.animate_panel(false)
	_close_equip_popup()
	platform.hide()


func _on_armory_panel_hidden() -> void:
	hide()


func _on_category_button_pressed(category_id: String, tab_button: AnimatedButton) -> void:
	for child in tab_button_container.get_children():
		var tab_button_panel_stylebox: StyleBoxFlat = child.get_child(0).get_theme_stylebox("panel").duplicate()
		tab_button_panel_stylebox.bg_color = Color("3d70ff") if child == tab_button else Color("1d222b")
		child.get_child(0).add_theme_stylebox_override("panel", tab_button_panel_stylebox)
	current_category_id = category_id
	_render_category(category_id)


func _render_category(category_id: String) -> void:
	for child in item_card_container.get_children():
		child.queue_free()
	var category_item_ids := Data.CATEGORY_ITEM_IDS[category_id]
	var category_items := Data.CATEGORIES[category_id]
	for item_id in category_item_ids:
		for item in player["items"]:
			if item["itemId"] == item_id:
				var new_item_card := ITEM_CARD.instantiate()
				item_card_container.add_child(new_item_card)
				new_item_card.pressed.connect(_on_item_card_pressed.bind(category_id, item_id, new_item_card))
				new_item_card.render_item_card(category_id, item_id, player["loadout"][category_id + "Id"] == item_id)


func _on_item_card_pressed(category_id: String, item_id: String, item_card: AnimatedButton) -> void:
	if player["loadout"][category_id + "Id"] == item_id:
		return
	selected_category_id = category_id
	selected_item_id = item_id
	selected_item_card.render_item_card(category_id, item_id)
	var card_position: Vector2 = get_global_transform().affine_inverse() * item_card.global_position
	equip_popup.position = card_position - Vector2(32, 32)
	equip_popup.position = equip_popup.position.clamp(Vector2.ZERO, (size - equip_popup.size).max(Vector2.ZERO))
	equip_popup.show()


func _on_equip_button_pressed() -> void:
	player["loadout"][selected_category_id + "Id"] = selected_item_id
	_render_category(current_category_id)
	_close_equip_popup()
	lobby.update_loadout_requested.emit(player["loadout"])


func _close_equip_popup() -> void:
	equip_popup.hide()
	selected_category_id = ""
	selected_item_id = ""
