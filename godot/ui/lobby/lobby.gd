extends Control

signal play_toggled(toggled_on: bool)
signal mode_changed(mode_id: String)
signal friend_invite_requested
signal player_invited(player_id: String)
signal invite_accepted(invite_id: String)

const PLAY_BUTTON_PANEL_TEXTURES := {
	"normal": preload("res://ui/lobby/play_button_normal.png"),
	"pressed": preload("res://ui/lobby/play_button_pressed.png"),
}

@onready var play_button := %PlayButton
@onready var play_button_panel := %PlayButtonPanel
@onready var play_button_label := %PlayButtonLabel

@onready var add_friends_button: Button = %FriendsPanel.add_friends_button

@onready var name_label := %NameLabel
@onready var trophies_label := %TrophiesLabel

@onready var game_mode_label := %GameModeLabel
@onready var ranked_label := %RankedLabel
@onready var game_mode_texture_rect := %GameModeTextureRect

@onready var main_panel := %MainPanel
@onready var friends_panel := %FriendsPanel
@onready var game_mode_panel := %GameModePanel
@onready var armory_screen := %ArmoryScreen

@onready var platform_area := %PlatformArea

@onready var platforms := [
	%Platform2,
	%Platform3,
	%Platform,
	%Platform4,
]

@onready var version_label := %VersionLabel


func _ready() -> void:
	# DEBUG
	main_panel.show()
	friends_panel.hide()
	game_mode_panel.hide()
	platform_area.show()
	armory_screen.show()
	armory_screen.armory_panel.hide()
	armory_screen.platform.hide()
	
	game_mode_panel.render_game_mode_panel()
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version")


func render_lobby(lobby: Dictionary, player: Dictionary, friends: Dictionary) -> void:
	var local_lobby_player: Dictionary
	for lobby_player in lobby["players"]:
		if lobby_player["id"] == player["id"]:
			local_lobby_player = lobby_player
			break
	
	name_label.text = player["displayName"]
	trophies_label.text = str(int(player["trophies"]))
	
	play_button.disabled = lobby["status"] != "open"
	play_button.button_pressed = local_lobby_player["ready"]
	var play_button_panel_stylebox: StyleBoxTexture = play_button_panel.get_theme_stylebox("panel")
	play_button_panel_stylebox.texture = PLAY_BUTTON_PANEL_TEXTURES["pressed" if local_lobby_player["ready"] else "normal"]
	if lobby["players"].size() == 1:
		play_button_label.text = "PLAY"
	else:
		play_button_label.text = "READY"
	
	var mode := Data.MODES[lobby["modeId"]]
	game_mode_label.text = mode.display_name
	ranked_label.text = "RANKED" if mode.ranked else "UNRANKED"
	var ranked_label_color := Color("dcb742") if mode.ranked else Color("3d70ff")
	ranked_label.add_theme_color_override("font_color", ranked_label_color)
	game_mode_texture_rect.texture = mode.icon_texture
	
	for platform in platforms:
		platform.hide()
	platforms[0].render_platform(local_lobby_player, local_lobby_player["ready"], true)
	var next_platform_index := 1
	for lobby_player in lobby["players"]:
		if lobby_player["id"] == local_lobby_player["id"]:
			continue
		platforms[next_platform_index].render_platform(lobby_player, lobby_player["ready"], false)
		next_platform_index += 1
	
	friends_panel.render_friends_panel(friends["players"])
	armory_screen.render_armory_screen(player)
	
	# DEBUG
	for invite in friends["lobbyInvites"]:
		invite_accepted.emit(invite["inviteId"])


func _on_friends_panel_add_friends_button_pressed() -> void:
	friend_invite_requested.emit()


func _on_friends_panel_player_invited(playerId: String) -> void:
	player_invited.emit(playerId)


func _on_game_mode_panel_game_mode_selected(mode_id: String) -> void:
	mode_changed.emit(mode_id)


func _on_button_5_pressed() -> void:
	get_parent().get_parent()._on_native_url_received(DisplayServer.clipboard_get())


func _on_shop_button_pressed() -> void:
	pass # Replace with function body.


func _on_armory_button_pressed() -> void:
	armory_screen.open_armory_screen()


func _on_friends_button_pressed() -> void:
	friends_panel.animate_panel(true)


func _on_ranks_button_pressed() -> void:
	pass # Replace with function body.


func _on_chest_button_pressed() -> void:
	pass # Replace with function body.


func _on_game_mode_button_pressed() -> void:
	game_mode_panel.animate_panel(true)


func _on_play_button_toggled(toggled_on: bool) -> void:
	play_toggled.emit(toggled_on)
