extends TextureRect

signal create_guest_requested(displayName: String)
signal start_signup_requested(displayName: String, email: String, on_completed: Callable)
signal verify_signup_requested(email: String, code: String)
signal start_login_requested(email: String, on_completed: Callable)
signal verify_login_requested(email: String, code: String)

var email: String
var previous_state: String

@onready var guest := %Guest
@onready var signup := %Signup
@onready var login := %Login
@onready var verify := %Verify


func _on_signup_start_signup_requested(displayName: String, email: String) -> void:
	previous_state = "signup"
	self.email = email
	start_signup_requested.emit(displayName, email, _on_start_signup_completed)


func _on_start_signup_completed(success: bool) -> void:
	if success:
		signup.hide()
		verify.show_verify()


func _on_signup_login_pressed() -> void:
	signup.hide()
	login.show_login()


func _on_signup_guest_pressed() -> void:
	previous_state = "signup"
	signup.hide()
	guest.show_guest()


func _on_login_start_login_requested(email: String) -> void:
	previous_state = "login"
	self.email = email
	start_login_requested.emit(email, _on_start_login_completed)


func _on_start_login_completed(success: bool) -> void:
	if success:
		login.hide()
		verify.show_verify()


func _on_login_signup_pressed() -> void:
	login.hide()
	signup.show_signup()


func _on_login_guest_pressed() -> void:
	previous_state = "login"
	login.hide()
	guest.show_guest()


func _on_guest_create_guest_requested(displayName: String) -> void:
	create_guest_requested.emit(displayName)


func _on_guest_back_pressed() -> void:
	guest.hide()
	if previous_state == "signup":
		signup.show_signup()
	else:
		login.show_login()


func _on_verify_code_entered(code: String) -> void:
	if previous_state == "signup":
		verify_signup_requested.emit(email, code)
	else:
		verify_login_requested.emit(email, code)


func _on_verify_back_pressed() -> void:
	verify.hide()
	if previous_state == "signup":
		signup.show_signup()
	else:
		login.show_login()
