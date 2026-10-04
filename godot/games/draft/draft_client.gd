extends Node

signal ended
signal match_over

const DraftScreen = preload("res://ui/draft_screen/draft_screen.tscn")
const Overlay := preload("res://ui/overlay/overlay.tscn")
const Gameover := preload("res://ui/gameover/gameover.tscn")
const Loading := preload("res://ui/loading/loading.tscn")

enum GameState {
	DRAFT,
	FIGHT,
	GAMEOVER,
}

var state: GameState

var map_id: String
var player_names: Dictionary = {}

var draft_screen: Control

@onready var ui := get_node("/root/Controller/UI")
@onready var game_net := get_node("/root/Controller/Net/GameNet")
@onready var logic := $Logic


func _ready() -> void:
	logic.spawn_map(map_id)
	logic.player_names = player_names
	game_net.connect("state_sync_received", _on_net_state_sync_received)


func _change_state(new_state: GameState, data = null) -> void:
	_exit_state(data)
	state = new_state
	_enter_state(data)


func _enter_state(data = null) -> void:
	if state == GameState.DRAFT:
		var new_draft_screen = DraftScreen.instantiate()
		new_draft_screen.connect("draft_pick_made", _on_draft_screen_draft_pick_made)
		new_draft_screen.connect("draft_finished", _on_draft_screen_draft_finished)
		new_draft_screen.draft_options = data["draft_options"]
		var draft_picks := _to_int_array(data.get("draft_picks", []))
		var manual_pick_count := int(data.get("draft_manual_pick_count", draft_picks.size()))
		new_draft_screen.draft_result = draft_picks.slice(0, manual_pick_count)
		new_draft_screen.time_limit_seconds = float(data.get("draft_time_limit", 30.0))
		new_draft_screen.elapsed_seconds = float(data.get("draft_elapsed", 0.0))
		new_draft_screen.submitted = data.get("draft_submitted", false)
		new_draft_screen.input_locked = data.get("draft_submitted", false)
		ui.add_child(new_draft_screen)
		draft_screen = new_draft_screen
		if data.get("draft_auto_picked", false):
			new_draft_screen.animate_server_picks(draft_picks)
	elif state == GameState.FIGHT:
		var new_overlay = Overlay.instantiate()
		logic.overlay = new_overlay
		ui.add_child(new_overlay)
		logic.set_physics_process(true)
	elif state == GameState.GAMEOVER:
		logic.set_physics_process(false)
		emit_signal("match_over")
		var new_gameover = Gameover.instantiate()
		new_gameover.ranking = _get_display_ranking(data["ranking"])
		ui.add_child(new_gameover)
		new_gameover.continue_button.connect("pressed", _on_gameover_continue_pressed)


func _exit_state(data = null) -> void:
	for child in ui.get_children():
		child.queue_free()
	draft_screen = null


func _on_net_state_sync_received(state_sync: StateSync) -> void:
	_change_state(state_sync.phase, state_sync.payload)


func _on_draft_screen_draft_finished(draft_result: Array[int]) -> void:
	var new_game_request := GameRequest.new()
	new_game_request.type = GameRequest.Type.DRAFT_RESULT
	new_game_request.payload = draft_result
	game_net.send_game_request(new_game_request)


func _on_draft_screen_draft_pick_made(draft_result: Array[int]) -> void:
	var new_game_request := GameRequest.new()
	new_game_request.type = GameRequest.Type.DRAFT_PROGRESS
	new_game_request.payload = draft_result
	game_net.send_game_request(new_game_request)


func _on_gameover_continue_pressed() -> void:
	emit_signal("ended")


func _get_display_ranking(ranking: Array) -> Array[String]:
	var display_ranking: Array[String] = []
	for player_id in ranking:
		var id := str(player_id)
		display_ranking.append(str(player_names.get(id, id)))
	return display_ranking


func _to_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result
