extends Control

signal loadout_updated(loadout: Dictionary)
signal closed

const ITEM_ENTRY := preload("res://ui/lobby/armory_screen/item_entry.tscn")

var player: Dictionary
var current_category_id := "melee"

@onready var armory_panel := %ArmoryPanel
@onready var item_card_container := %ItemCardContainer
@onready var tab_button_container := %TabButtonContainer
@onready var platform := %Platform

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


func render_armory(player: Dictionary) -> void:
	self.player = player
	platform.render_platform(player, false, true)
	_render_category(current_category_id)


func _render_category(category_id: String) -> void:
	for child in item_card_container.get_children():
		child.queue_free()
	var category_item_ids := Data.CATEGORY_ITEM_IDS[category_id]
	var category_items := Data.CATEGORIES[category_id]
	for item_id in category_item_ids:
		for item in player["items"]:
			if item["itemId"] == item_id:
				var new_item_entry := ITEM_ENTRY.instantiate()
				item_card_container.add_child(new_item_entry)
				new_item_entry.item_equipped.connect(_on_item_equipped.bind(category_id, item_id))
				new_item_entry.render_item_entry(category_id, item_id, player["loadout"])


func show_armory() -> void:
	armory_panel.animate_panel(true)
	platform.show()
	show()
	_on_category_button_pressed("melee", melee_button)


func hide_armory() -> void:
	armory_panel.animate_panel(false)
	platform.hide()


func _on_category_button_pressed(category_id: String, tab_button: AnimatedButton) -> void:
	for child in tab_button_container.get_children():
		var tab_button_panel_stylebox: StyleBoxFlat = child.get_child(0).get_theme_stylebox("panel").duplicate()
		tab_button_panel_stylebox.bg_color = Color("3d70ff") if child == tab_button else Color("1d222b")
		child.get_child(0).add_theme_stylebox_override("panel", tab_button_panel_stylebox)
	current_category_id = category_id
	_render_category(category_id)


func _on_item_equipped(category_id: String, item_id: String) -> void:
	player["loadout"][category_id + "Id"] = item_id
	loadout_updated.emit(player["loadout"])


func _on_close_button_pressed() -> void:
	closed.emit()


func _on_armory_panel_hidden() -> void:
	hide()
