extends Control

<<<<<<< HEAD
signal continue_pressed

const PLATFORM := preload("res://ui/lobby/platform/platform.tscn")
const OWN_COLOR := Color("8be7bb")
const OPPONENT_COLOR := Color("ffaaa0")
const LOADOUT_SLOTS := ["ranged", "melee", "armour", "ability"]

@onready var continue_button: Button = %Continue
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var trophies_label: Label = %Trophies
@onready var own_heading: Label = %OwnHeading
@onready var opponent_heading: Label = %OpponentHeading
@onready var own_players: HBoxContainer = %OwnPlayers
@onready var opponent_players: HBoxContainer = %OpponentPlayers
@onready var opponent_panel: PanelContainer = %OpponentPanel
@onready var versus_label: Label = %Versus


func render_gameover(data: Dictionary, player_id: String) -> void:
	_clear_players(own_players)
	_clear_players(opponent_players)
	var results: Array = data.get("results", [])
	var teams: Dictionary = {}
	var local_result: Dictionary = {}
	for entry in results:
		if not entry is Dictionary:
			continue
		var team_id := int(entry.get("teamId", -1))
		if not teams.has(team_id):
			teams[team_id] = []
		teams[team_id].append(entry)
		if str(entry.get("participantId", "")) == player_id:
			local_result = entry

	var ranked := bool(data.get("ranked", false))
	trophies_label.visible = ranked and data.has("trophyChange")
	if trophies_label.visible:
		var change := int(data["trophyChange"])
		trophies_label.text = "%s%d TROPHIES" % ["+" if change > 0 else "", change]
		trophies_label.modulate = OWN_COLOR if change >= 0 else OPPONENT_COLOR

	var show_opponent := teams.size() == 2 and not local_result.is_empty()
	opponent_panel.visible = show_opponent
	versus_label.visible = show_opponent
	if local_result.is_empty():
		title_label.text = "MATCH COMPLETE"
		title_label.modulate = Color.WHITE
		subtitle_label.text = "Your team result is unavailable."
		own_heading.text = "YOUR TEAM"
		return

	var local_team := int(local_result["teamId"])
	var placement := int(local_result.get("placement", 0))
	title_label.text = "VICTORY!" if placement == 1 else "MATCH COMPLETE"
	title_label.modulate = OWN_COLOR if placement == 1 else Color.WHITE
	subtitle_label.text = "%s  /  PLACED #%d OF %d TEAMS" % [
		"RANKED" if ranked else "UNRANKED", placement, teams.size()
	]
	own_heading.text = "YOUR TEAM  /  #%d" % placement
	# Put the local player first, without changing the received result array.
	var teammates: Array = teams[local_team].duplicate()
	for index in teammates.size():
		if str(teammates[index].get("participantId", "")) == player_id:
			var local = teammates.pop_at(index)
			teammates.push_front(local)
			break
	for entry in teammates:
		_add_player(own_players, entry, player_id, OWN_COLOR)
	if show_opponent:
		for team_id in teams:
			if team_id == local_team:
				continue
			var opponents: Array = teams[team_id]
			opponent_heading.text = "OPPONENTS  /  #%d" % int(opponents[0]["placement"])
			for entry in opponents:
				_add_player(opponent_players, entry, player_id, OPPONENT_COLOR)


func _clear_players(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_player(container: Container, result: Dictionary, player_id: String, accent: Color) -> void:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 300
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 16)
	container.add_child(card)

	var local := str(result.get("participantId", "")) == player_id
	var name_label := _label(str(result.get("displayName", "Player")), 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.y = 42
	name_label.modulate = accent
	card.add_child(name_label)
	card.add_child(_label("YOU" if local else "PLAYER", 18))

	var platform = PLATFORM.instantiate()
	platform.custom_minimum_size.y = 340
	platform.clip_contents = true
	card.add_child(platform)
	# Fit the lobby's existing artwork inside a Control-container cell.
	var artwork: Node2D = platform.get_node("CenterContainer/Control/Node2D")
	artwork.scale = Vector2(0.36, 0.36)
	artwork.position.y = -55
	var loadout: Dictionary = result.get("loadout", {})
	if Data.ARMOUR.has(str(loadout.get("armourId", ""))) and Data.MELEE.has(str(loadout.get("meleeId", ""))):
		platform.render_platform({
			"displayName": result.get("displayName", "Player"),
			"loadout": loadout,
		}, local)
	platform.get_node("CenterContainer/Control/Node2D/PlayerClient/Status").hide()

	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 10)
	card.add_child(items)
	for category in LOADOUT_SLOTS:
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_constant_override("separation", 8)
		items.add_child(slot)
		var item_id := str(loadout.get(category + "Id", ""))
		var catalog: Dictionary = Data.CATEGORIES[category]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(60, 84)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = item_id.replace("_", " ").capitalize()
		if catalog.has(item_id):
			icon.texture = catalog[item_id].card_texture
		slot.add_child(icon)
		slot.add_child(_label(category.to_upper(), 14))
		var item_name := _label(item_id.replace("_", " ").capitalize() if not item_id.is_empty() else "—", 16)
		item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(item_name)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _on_continue_pressed() -> void:
	continue_pressed.emit()
=======
var ranking: Array[String]

@onready var continue_button := $CenterContainer/VBoxContainer/Continue


func _ready() -> void:
	if ranking.is_empty():
		$CenterContainer/VBoxContainer/Label.text = "Match ended"
		return
	$CenterContainer/VBoxContainer/Label.text = "The winner is: " + ranking[0]
>>>>>>> origin/main
