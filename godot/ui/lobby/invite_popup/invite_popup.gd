extends AnimatedPopup

signal accept_invite_requested(invite_id: String)
signal decline_invite_requested(invite_id: String)

var invite_id: String

@onready var description_label := %DescriptionLabel
@onready var player_entry := %PlayerEntry


func _ready() -> void:
	hide()


func show_invite(lobby_invite: Dictionary) -> void:
	invite_id = lobby_invite["inviteId"]
	description_label.text = lobby_invite["sourcePlayer"]["displayName"] + " wants to team up with you!"
	player_entry.render_player_entry(lobby_invite["sourcePlayer"], false, false)
	animate_popup(true)


func _on_reject_button_pressed() -> void:
	decline_invite_requested.emit(invite_id)
	animate_popup(false)


func _on_accept_button_pressed() -> void:
	accept_invite_requested.emit(invite_id)
	animate_popup(false)
