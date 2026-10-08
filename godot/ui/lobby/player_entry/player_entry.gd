extends ShrinkButton

signal invite_pressed(player_id: String)

var player_id := ""
var invite_tween: Tween

@onready var display_name_label := %DisplayNameLabel
@onready var status_label := %StatusLabel
@onready var trophies_label := %TrophiesLabel
@onready var invite_popup := %InvitePopup


func render_player_entry(player: Dictionary, show_status: bool, invitable: bool) -> void:
	invite_popup.hide()
	status_label.text = ""
	player_id = ""
	display_name_label.text = player["displayName"]
	trophies_label.text = str(int(player["trophies"]))
	if show_status:
		match player["status"]:
			"open":
				status_label.text = "lobby"
			"matchmaking", "in-game":
				status_label.text = "in game"
			"offline":
				status_label.text = "offline"
	if invitable:
		player_id = player["id"]


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if invite_popup.visible:
		var local_mouse = invite_popup.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, invite_popup.size).has_point(local_mouse):
			_close_invite_popup()


func _open_invite_popup() -> void:
	if not player_id:
		return
	if invite_tween:
		invite_tween.kill()
	invite_popup.pivot_offset = invite_popup.size / 2.0
	var center := get_global_transform_with_canvas() * (size * Vector2(2.0 / 3.0, 0.5))
	invite_popup.position = center - invite_popup.pivot_offset
	invite_popup.scale = Vector2.ONE * 0.01
	invite_popup.show()
	invite_tween = create_tween()
	invite_tween.tween_property(invite_popup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_invite_popup() -> void:
	if not invite_popup.is_visible_in_tree():
		return
	if invite_tween:
		invite_tween.kill()
	invite_tween = create_tween()
	invite_tween.tween_property(invite_popup, "scale", Vector2.ONE * 0.01, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	invite_tween.tween_callback(invite_popup.hide)


func _on_pressed() -> void:
	_open_invite_popup()


func _on_invite_popup_pressed() -> void:
	invite_pressed.emit(player_id)
	_close_invite_popup()
