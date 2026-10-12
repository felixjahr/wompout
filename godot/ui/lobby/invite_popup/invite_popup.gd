extends AnimatedPopup

var invite_id: String

@onready var lobby := get_parent()
@onready var description_label := %DescriptionLabel
@onready var player_entry := %PlayerEntry


func open(lobby_invite: Dictionary) -> void:
	invite_id = lobby_invite["inviteId"]
	description_label.text = lobby_invite["sourcePlayer"]["displayName"] + " wants to team up with you!"
	player_entry.render_player_entry(lobby_invite["sourcePlayer"], false, false)
	animate_popup(true)


func _close() -> void:
	animate_popup(false)


func _on_reject_button_pressed() -> void:
	lobby.decline_invite_requested.emit(invite_id)
	_close()


func _on_accept_button_pressed() -> void:
	lobby.accept_invite_requested.emit(invite_id)
	_close()
