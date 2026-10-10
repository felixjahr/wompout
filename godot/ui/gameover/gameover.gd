extends Control

signal continue_pressed

@onready var continue_button := %ContinueButton
@onready var ally_container := %AllyContainer
@onready var enemy_container := %EnemyContainer
@onready var trophies_container := %TrophiesContainer
@onready var trophies_label := %TrophiesLabel
@onready var title_label := %TitleLabel
@onready var screen_divider := %ScreenDivider


func render_gameover(data: Dictionary, player_id: String) -> void:
	trophies_container.visible = data["trophyChange"] != null
	if data["trophyChange"] != null:
		if data["trophyChange"] > 0:
			trophies_label.text = "+"
		else:
			trophies_label.text = ""
		trophies_label.text += str(int(data["trophyChange"]))
	
	for container in [ally_container, enemy_container]:
		for child in container.get_children():
			child.hide()

	var teams: Dictionary = {}
	var own_team_id: int
	var own_placement: int

	for result in data["results"]:
		var team_id = result["teamId"]
		if not teams.has(team_id):
			teams[team_id] = []
		teams[team_id].append(result)

		if result["participantId"] == player_id:
			own_team_id = team_id
			own_placement = int(result["placement"])
	
	var title_label_color: Color
	if teams.size() == 2:
		title_label.text = "VICTORY" if own_placement == 1 else "DEFEAT"
		title_label_color = Color("f5b51b") if own_placement == 1 else Color("c21b16")
	else:
		title_label.text = "YOU ARE #" + str(own_placement)
		title_label_color = Color("f5b51b") if own_placement == 1 else Color.WHITE
	title_label.add_theme_color_override("font_color", title_label_color)
	
	var show_enemies := teams.size() == 2
	enemy_container.visible = show_enemies
	screen_divider.visible = show_enemies
	
	for team_id in teams:
		var is_ally: bool = team_id == own_team_id
		if not is_ally and not show_enemies:
			continue

		var container = ally_container if is_ally else enemy_container

		for i in teams[team_id].size():
			container.get_child(i).render_platform(
				teams[team_id][i], 
				false, 
				teams[team_id][i]["participantId"] == player_id
			)
			container.get_child(i).show()


func _on_continue_button_pressed() -> void:
	continue_pressed.emit()
