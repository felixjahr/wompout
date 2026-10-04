class_name ModeClient
extends Node

enum ModeState {
	PREPARING,
	FIGHT,
	GAMEOVER,
}

const Overlay := preload("res://ui/overlay/overlay.tscn")

var state := ModeState.PREPARING

var map_id: String
var participant_names: Dictionary = {}
var ui: Node

@onready var ui_container := get_node("/root/Controller/UIContainer")
@onready var game_net := get_node("/root/Controller/Net/GameNet")
@onready var logic := $Logic


func _ready() -> void:
	logic.participant_names = participant_names
	logic.spawn_map(map_id)
	logic.set_physics_process(false)
	game_net.connect("state_sync_received", _on_net_state_sync_received)


func _change_state(new_state: ModeState, data = null) -> void:
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
	match state:
		ModeState.PREPARING:
			logic.set_physics_process(false)
			_enter_preparing(data)
		ModeState.FIGHT:
			var overlay := Overlay.instantiate()
			logic.overlay = overlay
			ui_container.add_child(overlay)
			_enter_fight(data)
			logic.set_physics_process(true)
		ModeState.GAMEOVER:
			logic.set_physics_process(false)
			_enter_gameover(data)


func _enter_preparing(data) -> void:
	pass


func _enter_fight(data) -> void:
	pass


func _enter_gameover(data) -> void:
	pass


func _exit_state(data = null) -> void:
	for child in ui_container.get_children():
		child.queue_free()
	ui = null
	logic.overlay = null


func _on_net_state_sync_received(state_sync: StateSync) -> void:
	_change_state(state_sync.phase, state_sync.payload)
