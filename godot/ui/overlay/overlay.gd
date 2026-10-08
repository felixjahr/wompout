extends Control

var jumping := false
var attacking := false
var ability := false
var current_weapon := 0

var attack_direction := Vector2.ZERO
var attack_weapon := 0

@onready var jump_button := $JumpButton
@onready var ability_button := $AbilityButton
@onready var dpad := $Dpad
@onready var melee_joystick := $MeleeJoystick
@onready var ranged_joystick := $RangedJoystick
@onready var logic: Node = get_parent().get_parent().game.logic


func poll() -> ParticipantInput:
	var input := ParticipantInput.new()
	if not attacking:
		if melee_joystick.is_active:
			current_weapon = 0
			input.aim_direction = melee_joystick.output
		elif ranged_joystick.is_active:
			current_weapon = 1
			input.aim_direction = ranged_joystick.output
		input.current_weapon = current_weapon
	else:
		input.aim_direction = attack_direction
		input.current_weapon = attack_weapon
	
	input.jumping = jumping
	input.ability = ability
	input.attacking = attacking
	input.direction = clampi(signf(Input.get_axis("move_left", "move_right") + dpad.output), -1, 1)
	
	jumping = false
	ability = false
	attacking = false
	
	return input


func apply_snapshot(snapshot: ParticipantSnapshot) -> void:
	if ability_button.ability_id != snapshot.ability_id:
		ability_button.set_ability(snapshot.ability_id)
	var total_charge = Data.ABILITY[snapshot.ability_id].charge
	var charge_progress: float = float(snapshot.ability_charge) / float(total_charge)
	ability_button.set_texture_value(charge_progress * 100.0)


func _input(event: InputEvent) -> void:
	var input_controls := [
		jump_button,
		ability_button,
		dpad,
		melee_joystick,
		ranged_joystick
	]
	for control in input_controls:
		control.handle_input(event)
		if get_viewport().is_input_handled():
			return
	if event.is_action_pressed("jump"):
		jumping = true
	elif event.is_action_pressed("ability"):
		ability = true


func _on_jump_button_pressed() -> void:
	jumping = true


func _on_ability_button_pressed() -> void:
	ability = true


func _on_melee_joystick_released(direction: Vector2) -> void:
	attacking = true
	attack_direction = direction
	attack_weapon = 0
	current_weapon = 0


func _on_ranged_joystick_released(direction: Vector2) -> void:
	attacking = true
	attack_direction = direction
	attack_weapon = 1
	current_weapon = 1


func _get_mouse_aim_direction() -> Vector2:
	var local_player: Node2D = logic.players.get(logic.local_player_id)
	var pivot: Vector2 = local_player.right_shoulder.global_position
	return pivot.direction_to(local_player.get_global_mouse_position())
