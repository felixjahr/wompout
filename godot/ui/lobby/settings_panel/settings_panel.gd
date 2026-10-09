extends AnimatedPanel

signal logout_requested
signal start_link_requested(email: String, on_completed: Callable)
signal verify_link_requested(email: String, code: String, on_completed: Callable)
signal closed

var email: String

@onready var main := %Main
@onready var link := %Link
@onready var verify := %Verify

@onready var email_label := %EmailLabel
@onready var link_button := %LinkButton
@onready var link_label := %LinkLabel
@onready var logout_button := %LogoutButton
@onready var version_label := %VersionLabel


func _ready() -> void:
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version")


func render_settings(player: Dictionary) -> void:
	if player["email"] == null:
		email_label.hide()
		link_button.show()
		link_label.text = "LINK EMAIL"
		logout_button.hide()
	else:
		email_label.show()
		email_label.text = "EMAIL: " + player["email"]
		link_button.show()
		link_label.text = "CHANGE EMAIL"
		logout_button.show()


func _on_link_button_pressed() -> void:
	main.hide()
	link.show_link()


func _on_link_start_link_requested(email: String) -> void:
	self.email = email
	start_link_requested.emit(email, _on_start_link_completed)


func _on_start_link_completed(success: bool) -> void:
	if success:
		link.hide()
		verify.show_verify()


func _on_link_back_pressed() -> void:
	main.show()
	link.hide()


func _on_verify_code_entered(code: String) -> void:
	verify_link_requested.emit(email, code, _on_verify_link_completed)


func _on_verify_link_completed(success: bool) -> void:
	if success:
		verify.hide()
		main.show()


func _on_verify_back_pressed() -> void:
	verify.hide()
	link.show_link()


func _on_log_out_button_pressed() -> void:
	logout_requested.emit()


func _on_close_button_pressed() -> void:
	main.show()
	link.hide()
	verify.hide()
	closed.emit()
