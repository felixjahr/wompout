extends Control

signal logout_requested
signal start_link_requested(email: String, on_completed: Callable)
signal verify_link_requested(email: String, code: String, on_completed: Callable)
signal invite_player_requested(player_id: String)
signal accept_invite_requested(invite_id: String)
signal decline_invite_requested(invite_id: String)
signal leave_lobby_requested
signal update_mode_requested(mode_id: String)
signal update_ready_requested(ready: bool)
signal update_loadout_requested(loadout: Dictionary)
signal create_invite_requested
signal open_chest_requested(on_completed: Callable)

signal resource_opened(resource: String)
signal resource_closed(resource: String)

const PLAY_BUTTON_PANEL_TEXTURES := {
	"normal": preload("res://ui/lobby/play_button_normal.png"),
	"pressed": preload("res://ui/lobby/play_button_pressed.png"),
}

var pending_lobby_invites := []
var local_player_id: String

@onready var platforms := [
	%Platform2,
	%Platform3,
	%Platform,
	%Platform4,
]

@onready var name_label := %NameLabel
@onready var trophies_label := %TrophiesLabel
@onready var coins_label := %CoinsLabel
@onready var gems_label := %GemsLabel

@onready var leave_button := %LeaveButton

@onready var chest_progress_bar := %ChestProgressBar
@onready var chest_label := %ChestLabel

@onready var game_mode_label := %GameModeLabel
@onready var ranked_label := %RankedLabel
@onready var game_mode_texture_rect := %GameModeTextureRect

@onready var play_button := %PlayButton
@onready var play_button_panel := %PlayButtonPanel
@onready var play_button_label := %PlayButtonLabel

@onready var platform_area := %PlatformArea
@onready var upper_bar := %UpperBar
@onready var side_buttons := %SideButtons
@onready var lower_bar := %LowerBar

@onready var invite_popup := %InvitePopup
@onready var settings_screen := %SettingsScreen
@onready var chest_screen := %ChestScreen
@onready var game_mode_screen := %GameModeScreen
@onready var armory_screen := %ArmoryScreen
@onready var friends_screen := %FriendsScreen
@onready var rankings_screen := %RankingsScreen


func update_player(player: Dictionary) -> void:
	name_label.text = player["displayName"]
	trophies_label.text = str(int(player["trophies"]))
	coins_label.text = str(int(player["coins"]))
	gems_label.text = str(int(player["gems"]))
	var required_chest_progress := int(player["chestProgress"]["requiredProgress"])
	var chest_progress := int(player["chestProgress"]["progress"])
	if int(player["chestProgress"]["readyChests"]) == 0:
		chest_progress_bar.max_value = required_chest_progress
		chest_progress_bar.value = chest_progress
		chest_label.text = str(chest_progress) + "/" + str(required_chest_progress)
	else:
		chest_progress_bar.value = chest_progress_bar.max_value
		chest_label.text = "READY"
	
	settings_screen.update_player(player)
	armory_screen.update_player(player)


func update_lobby(lobby: Dictionary) -> void:
	var local_lobby_player: Dictionary
	for lobby_player in lobby["players"]:
		if lobby_player["id"] == local_player_id:
			local_lobby_player = lobby_player
			break
	play_button.disabled = lobby["status"] != "open"
	play_button.set_pressed_no_signal(local_lobby_player["ready"])
	var play_button_panel_stylebox: StyleBoxTexture = play_button_panel.get_theme_stylebox("panel")
	play_button_panel_stylebox.texture = PLAY_BUTTON_PANEL_TEXTURES["pressed" if local_lobby_player["ready"] else "normal"]
	if lobby["players"].size() == 1:
		play_button_label.text = "PLAY"
		leave_button.hide()
	else:
		play_button_label.text = "READY"
		leave_button.show()
	var mode := Data.MODES[lobby["modeId"]]
	game_mode_label.text = mode.display_name
	ranked_label.text = "RANKED" if mode.ranked else "UNRANKED"
	var ranked_label_color := Color("f5b51b") if mode.ranked else Color("3d70ff")
	ranked_label.add_theme_color_override("font_color", ranked_label_color)
	game_mode_texture_rect.texture = mode.icon_texture
	for platform in platforms:
		platform.hide()
	platforms[0].render_platform(local_lobby_player, local_lobby_player["ready"], true)
	platforms[0].show()
	var next_platform_index := 1
	for lobby_player in lobby["players"]:
		if lobby_player["id"] == local_lobby_player["id"]:
			continue
		platforms[next_platform_index].render_platform(lobby_player, lobby_player["ready"], false)
		platforms[next_platform_index].show()
		next_platform_index += 1
	
	friends_screen.update_lobby(lobby)


func update_lobby_invites(lobby_invites: Array) -> void:
	var current_id := ""
	if invite_popup.visible:
		current_id = invite_popup.invite_id
	var current_exists := false
	pending_lobby_invites.clear()
	for invite in lobby_invites:
		if invite["inviteId"] == current_id:
			current_exists = true
		else:
			pending_lobby_invites.append(invite)
	if invite_popup.visible and not current_exists:
		invite_popup.hide()
	_try_show_lobby_invites()


func update_friends(friends: Dictionary) -> void:
	friends_screen.update_friends(friends)


func update_rankings(rankings: Dictionary) -> void:
	rankings_screen.update_rankings(rankings)


func update_shop(shop: Dictionary) -> void:
	pass


func _on_invite_popup_hidden() -> void:
	_try_show_lobby_invites()


func _try_show_lobby_invites() -> void:
	if pending_lobby_invites.size() > 0 and not invite_popup.visible:
		invite_popup.open(pending_lobby_invites.pop_front())
 

func _on_play_button_toggled(toggled_on: bool) -> void:
	update_ready_requested.emit(toggled_on)


func _on_leave_button_pressed() -> void:
	leave_lobby_requested.emit()


func _on_settings_button_pressed() -> void:
	settings_screen.open()


func _on_chest_button_pressed() -> void:
	open_chest_requested.emit(_on_open_chest_completed)


func _on_open_chest_completed(response: Dictionary) -> void:
	if response["ok"]:
		chest_screen.open(response["data"])


func _on_game_mode_button_pressed() -> void:
	game_mode_screen.open()


func _on_shop_button_pressed() -> void:
	pass


func _on_armory_button_pressed() -> void:
	armory_screen.open()


func _on_friends_button_pressed() -> void:
	friends_screen.open()


func _on_rankings_button_pressed() -> void:
	rankings_screen.open()
