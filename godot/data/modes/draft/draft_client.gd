extends ModeClient

const DraftScreen = preload("res://ui/draft_screen/draft_screen.tscn")


func _enter_preparing(data) -> void:
	ui = DraftScreen.instantiate()
	
	ui.draft_pick_made.connect(_on_draft_screen_draft_pick_made)
	ui.draft_finished.connect(_on_draft_screen_draft_finished)
	ui.draft_options.assign(data["draft_options"])
	
	var picks := _to_int_array(data.get("draft_picks", []))
	var manual_pick_count := clampi(int(data.get("draft_manual_pick_count", picks.size())), 0, picks.size())
	
	ui.draft_result = picks.slice(0, manual_pick_count)
	ui.time_limit_seconds = float(data.get("draft_time_limit", 10.0))
	ui.elapsed_seconds = float(data.get("draft_elapsed", 0.0))
	ui.submitted = bool(data.get("draft_submitted", false))
	ui.input_locked = ui.submitted

	ui_container.add_child(ui)
	
	if bool(data.get("draft_auto_picked", false)):
		ui.animate_server_picks(picks)


func _on_draft_screen_draft_finished(draft_result: Array[int]) -> void:
	var new_game_request := GameRequest.new()
	new_game_request.type = GameRequest.Type.DRAFT_RESULT
	new_game_request.payload = draft_result.duplicate()
	game_net.send_game_request(new_game_request)


func _on_draft_screen_draft_pick_made(draft_result: Array[int]) -> void:
	var new_game_request := GameRequest.new()
	new_game_request.type = GameRequest.Type.DRAFT_PROGRESS
	new_game_request.payload = draft_result.duplicate()
	game_net.send_game_request(new_game_request)


func _to_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result
