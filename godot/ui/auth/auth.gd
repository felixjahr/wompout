extends TextureRect

signal create_guest_requested(display_name: String, on_completed: Callable)
signal start_signup_requested(display_name: String, email: String, on_completed: Callable)
signal verify_signup_requested(email: String, code: String, on_completed: Callable)
signal start_login_requested(email: String, on_completed: Callable)
signal verify_login_requested(email: String, code: String, on_completed: Callable)

var email: String
var previous_state: String
var request_pending := false

@onready var guest := %Guest
@onready var signup := %Signup
@onready var login := %Login
@onready var verify := %Verify


func _on_signup_start_signup_requested(display_name: String, email: String) -> void:
	if request_pending:
		return
	request_pending = true
	previous_state = "signup"
	self.email = email
	start_signup_requested.emit(display_name, email, _on_start_signup_completed)


func _on_start_signup_completed(response: Dictionary) -> void:
	request_pending = false
	if response["ok"]:
		signup.hide()
		verify.show_verify()


func _on_signup_login_pressed() -> void:
	if request_pending:
		return
	signup.hide()
	login.show_login()


func _on_signup_guest_pressed() -> void:
	if request_pending:
		return
	previous_state = "signup"
	signup.hide()
	guest.show_guest()


func _on_login_start_login_requested(email: String) -> void:
	if request_pending:
		return
	request_pending = true
	previous_state = "login"
	self.email = email
	start_login_requested.emit(email, _on_start_login_completed)


func _on_start_login_completed(response: Dictionary) -> void:
	request_pending = false
	if response["ok"]:
		login.hide()
		verify.show_verify()


func _on_login_signup_pressed() -> void:
	if request_pending:
		return
	login.hide()
	signup.show_signup()


func _on_login_guest_pressed() -> void:
	if request_pending:
		return
	previous_state = "login"
	login.hide()
	guest.show_guest()


func _on_guest_create_guest_requested(display_name: String) -> void:
	if request_pending:
		return
	request_pending = true
	create_guest_requested.emit(display_name, _on_auth_completed)


func _on_guest_back_pressed() -> void:
	if request_pending:
		return
	guest.hide()
	if previous_state == "signup":
		signup.show_signup()
	else:
		login.show_login()


func _on_verify_code_entered(code: String) -> void:
	if request_pending:
		return
	request_pending = true
	if previous_state == "signup":
		verify_signup_requested.emit(email, code, _on_auth_completed)
	else:
		verify_login_requested.emit(email, code, _on_auth_completed)


func _on_verify_back_pressed() -> void:
	if request_pending:
		return
	verify.hide()
	if previous_state == "signup":
		signup.show_signup()
	else:
		login.show_login()


func _on_auth_completed(response: Dictionary) -> void:
	request_pending = false
